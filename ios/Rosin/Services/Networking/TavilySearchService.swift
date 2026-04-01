import Foundation

struct TavilySearchResult {
    let title: String
    let url: String
    let content: String
}

struct TavilySearchResponse {
    let results: [TavilySearchResult]

    var formattedContext: String {
        let lines = results.enumerated().map { i, r in
            "[\(i + 1)] \(r.title)\n    \(r.url)\n    \(r.content)"
        }
        return """
        You have access to the following live web search results. \
        Use them to ground your answer with current, up-to-date facts. \
        Always prefer this information over your training data when they conflict.

        Sources:
        \(lines.joined(separator: "\n\n"))
        """
    }

    var sourceSummary: String {
        results.enumerated().map { i, r in
            "  [\(i + 1)] \(r.title) — \(r.url)"
        }.joined(separator: "\n")
    }
}

enum TavilySearchService {
    static func search(query: String, apiKey: String, maxResults: Int = 5) async throws -> TavilySearchResponse {
        let url = URL(string: "https://api.tavily.com/search")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": maxResults,
            "search_depth": "basic",
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
            return TavilySearchResult(title: title, url: url, content: content)
        }

        return TavilySearchResponse(results: results)
    }
}
