import Foundation

enum ExaSearchService {
    static func search(query: String, apiKey: String, maxResults: Int = 8) async throws -> TavilySearchResponse {
        let url = URL(string: "https://api.exa.ai/search")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "query": query,
            "type": "auto",
            "numResults": maxResults,
            "contents": [
                "text": ["maxCharacters": 1000]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Exa] Search failed with status %d", statusCode)
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawResults = json["results"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let results = rawResults.compactMap { dict -> TavilySearchResult? in
            guard let title = dict["title"] as? String,
                  let url = dict["url"] as? String else { return nil }
            // Exa uses "text" instead of "content"
            let content = dict["text"] as? String ?? dict["content"] as? String ?? ""
            let score = TavilySearchService.publicScoreResult(title: title, url: url, content: content)
            return TavilySearchResult(title: title, url: url, content: content, credibility: score)
        }

        NSLog("[Exa] %d results scored: %@", results.count,
              results.map { "\($0.credibility):\(URL(string: $0.url)?.host ?? "?")" }.joined(separator: ", "))

        return TavilySearchResponse(results: results)
    }
}
