import Foundation

enum URLVerificationStatus: String {
    case verified = "VERIFIED: 200 OK"
    case broken = "BROKEN: 404/Error"
    case timeout = "TIMEOUT"
    case unchecked = "UNCHECKED"
}

struct TavilySearchResult {
    let title: String
    let url: String
    let content: String
    let credibility: Int
    var urlStatus: URLVerificationStatus = .unchecked
}

struct TavilySearchResponse {
    let results: [TavilySearchResult]

    var formattedContext: String {
        // Sort by credibility score descending
        let sorted = results.sorted { $0.credibility > $1.credibility }
        let verifiedCount = sorted.filter { $0.urlStatus == .verified }.count
        let lines = sorted.enumerated().map { i, r in
            "[\(i + 1)] [\(r.urlStatus.rawValue)] [CREDIBILITY: \(r.credibility)/100] \(r.title)\n    \(r.url)\n    \(r.content)"
        }
        return """
        LIVE WEB SEARCH RESULTS (ranked by source credibility).
        Each URL has been MACHINE-VERIFIED by fetching it \u{2014} this is not an LLM opinion.
        \(verifiedCount) of \(sorted.count) URLs returned HTTP 200 (confirmed to exist).
        Sources marked [VERIFIED: 200 OK] are CONFIRMED REAL PAGES. Their content is factual.
        Sources marked [BROKEN: 404/Error] may be fabricated \u{2014} ignore their claims.
        You MUST NOT claim a product "does not exist" if ANY verified source describes it.

        Sources:
        \(lines.joined(separator: "\n\n"))
        """
    }

    var sourceSummary: String {
        let sorted = results.sorted { $0.credibility > $1.credibility }
        return sorted.enumerated().map { i, r in
            let status = r.urlStatus == .verified ? "\u{2713}" : (r.urlStatus == .broken ? "\u{2717}" : "?")
            return "  [\(i + 1)] [\(status)] [CRED:\(r.credibility)] \(r.title) \u{2014} \(r.url)"
        }.joined(separator: "\n")
    }
}

/// Verify search result URLs by fetching them (HEAD request, 5s timeout).
/// Returns a new response with urlStatus set on each result.
enum URLVerifier {
    static func verify(response: TavilySearchResponse) async -> TavilySearchResponse {
        let verified = await withTaskGroup(of: (Int, URLVerificationStatus).self) { group in
            for (index, result) in response.results.enumerated() {
                group.addTask {
                    let status = await Self.checkURL(result.url)
                    return (index, status)
                }
            }
            var statuses: [Int: URLVerificationStatus] = [:]
            for await (index, status) in group {
                statuses[index] = status
            }
            return statuses
        }

        let updatedResults = response.results.enumerated().map { index, result in
            var updated = result
            updated.urlStatus = verified[index] ?? .unchecked
            return updated
        }

        let verifiedCount = updatedResults.filter { $0.urlStatus == .verified }.count
        let brokenCount = updatedResults.filter { $0.urlStatus == .broken }.count
        NSLog("[URLVerifier] %d verified, %d broken, %d timeout/unchecked",
              verifiedCount, brokenCount, updatedResults.count - verifiedCount - brokenCount)

        return TavilySearchResponse(results: updatedResults)
    }

    private static func checkURL(_ urlString: String) async -> URLVerificationStatus {
        guard let url = URL(string: urlString) else { return .broken }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if (200...399).contains(http.statusCode) {
                    return .verified
                } else {
                    return .broken
                }
            }
            return .unchecked
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                return .timeout
            }
            return .broken
        }
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

    /// Public wrapper so ExaSearchService can reuse the same scoring logic.
    static func publicScoreResult(title: String, url: String, content: String) -> Int {
        scoreResult(title: title, url: url, content: content)
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
