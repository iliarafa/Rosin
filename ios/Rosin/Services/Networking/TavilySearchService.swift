import Foundation

struct TavilySearchResult {
    let title: String
    let url: String
    let content: String
    let credibility: Int
}

struct TavilySearchResponse {
    let results: [TavilySearchResult]

    var formattedContext: String {
        // Sort by credibility score descending
        let sorted = results.sorted { $0.credibility > $1.credibility }
        let lines = sorted.enumerated().map { i, r in
            "[\(i + 1)] [CREDIBILITY: \(r.credibility)/100] \(r.title)\n    \(r.url)\n    \(r.content)"
        }
        return """
        LIVE WEB SEARCH RESULTS (ranked by source credibility).
        Prioritize high-credibility sources (\u{2265}80) over low-credibility ones (<60).
        Sources with credibility \u{2265}80 are from established, reputable outlets \u{2014} trust them over your training data.
        Sources with credibility <40 may be AI-generated or speculative \u{2014} treat with caution.

        Sources:
        \(lines.joined(separator: "\n\n"))
        """
    }

    var sourceSummary: String {
        let sorted = results.sorted { $0.credibility > $1.credibility }
        return sorted.enumerated().map { i, r in
            "  [\(i + 1)] [CRED:\(r.credibility)] \(r.title) \u{2014} \(r.url)"
        }.joined(separator: "\n")
    }
}

enum TavilySearchService {
    static func search(query: String, apiKey: String, maxResults: Int = 8) async throws -> TavilySearchResponse {
        let url = URL(string: "https://api.tavily.com/search")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": maxResults,
            "search_depth": "advanced",
            "include_answer": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawResults = json["results"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let results = rawResults.compactMap { dict -> TavilySearchResult? in
            guard let title = dict["title"] as? String,
                  let url = dict["url"] as? String,
                  let content = dict["content"] as? String else { return nil }
            let score = Self.scoreResult(title: title, url: url, content: content)
            return TavilySearchResult(title: title, url: url, content: content, credibility: score)
        }

        NSLog("[Tavily] %d results scored: %@", results.count,
              results.map { "\($0.credibility):\(URL(string: $0.url)?.host ?? "?")" }.joined(separator: ", "))

        return TavilySearchResponse(results: results)
    }

    /// Score a search result for source credibility (0–100).
    /// High scores = official/reputable sources. Low scores = spam/speculation.
    private static func scoreResult(title: String, url: String, content: String) -> Int {
        var score = 0
        let urlLower = url.lowercased()
        let contentLower = content.lowercased()
        let titleLower = title.lowercased()

        // Domain reputation (0–40 pts)
        let tier1 = ["apple.com", "google.com", "microsoft.com", "nvidia.com", "developer.apple.com"]
        let tier2 = ["macrumors.com", "theverge.com", "arstechnica.com", "techcrunch.com", "wired.com",
                     "reuters.com", "apnews.com", "bbc.com", "bbc.co.uk", "nytimes.com", "washingtonpost.com",
                     "bloomberg.com", "wsj.com", "cnbc.com", "ft.com"]
        let tier3 = ["tomshardware.com", "anandtech.com", "cnet.com", "engadget.com", "9to5mac.com",
                     "9to5google.com", "tomsguide.com", "pcmag.com", "zdnet.com", "gsmarena.com", "howtogeek.com"]
        let tier4 = ["wikipedia.org", "github.com", "stackoverflow.com", "medium.com", "substack.com"]

        if tier1.contains(where: { urlLower.contains($0) }) { score += 40 }
        else if tier2.contains(where: { urlLower.contains($0) }) { score += 35 }
        else if tier3.contains(where: { urlLower.contains($0) }) { score += 25 }
        else if tier4.contains(where: { urlLower.contains($0) }) { score += 15 }
        else { score += 5 }

        // Content quality signals (0–30 pts)
        let specificDataPattern = #"(\$\d|€\d|\d{3,}\s*(mah|gb|tb|ghz|mm)|(a\d{2}|m\d)\s*(pro|max|chip))"#
        if contentLower.range(of: specificDataPattern, options: .regularExpression) != nil {
            score += 15
        }
        let attributionPattern = #"(press release|official|announced|by\s+[A-Z][a-z]+ [A-Z])"#
        if content.range(of: attributionPattern, options: .regularExpression) != nil {
            score += 10
        }
        if content.count > 200 { score += 5 }

        // Red flags (negative pts)
        let aiSpamPattern = #"(in this article|let'?s explore|let'?s dive|in this comprehensive|everything you need to know)"#
        let combined = contentLower + " " + titleLower
        if combined.range(of: aiSpamPattern, options: .regularExpression) != nil {
            score -= 15
        }
        let speculativePattern = #"\b(rumored|reportedly|expected to|could be|might be|is said to|unconfirmed)\b"#
        if contentLower.range(of: speculativePattern, options: .regularExpression) != nil {
            score -= 10
        }
        let spamUrlPattern = #"(affiliate|ai-generated|sponsored)"#
        if urlLower.range(of: spamUrlPattern, options: .regularExpression) != nil || urlLower.components(separatedBy: "/").count > 8 {
            score -= 5
        }

        return max(0, min(100, score))
    }
}
