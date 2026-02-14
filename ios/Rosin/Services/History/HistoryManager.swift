import Foundation

enum HistoryManager {
    private static let key = "rosin_verification_history"
    private static let maxItems = 100

    static func save(_ item: VerificationHistoryItem) {
        var items = loadAll()
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadAll() -> [VerificationHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([VerificationHistoryItem].self, from: data) else {
            return []
        }
        return items
    }

    static func delete(_ id: UUID) {
        var items = loadAll()
        items.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    struct ProviderPairStat: Identifiable {
        let id: String
        let providerA: String
        let providerB: String
        let totalPairings: Int
        let disagreements: Int
        var rate: Double { totalPairings > 0 ? Double(disagreements) / Double(totalPairings) : 0 }
    }

    static func disagreementStats() -> (totalVerifications: Int, averageConfidence: Double?, pairs: [ProviderPairStat]) {
        let items = loadAll()
        let totalVerifications = items.count

        let scores = items.compactMap { $0.summary?.confidenceScore }
        let averageConfidence: Double? = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)

        var pairMap: [String: (totalPairings: Int, disagreements: Int, providerA: String, providerB: String)] = [:]

        for item in items {
            let contradictions = item.summary?.contradictions ?? []
            let providers = item.chain.map { $0.provider.rawValue }

            for i in 0..<providers.count {
                for j in (i + 1)..<providers.count {
                    let sorted = [providers[i], providers[j]].sorted()
                    let key = sorted.joined(separator: ":")

                    var entry = pairMap[key] ?? (0, 0, sorted[0], sorted[1])
                    entry.totalPairings += 1

                    let hasDisagreement = contradictions.contains { c in
                        guard c.stageA - 1 < item.chain.count, c.stageB - 1 < item.chain.count else { return false }
                        let cProviders = [item.chain[c.stageA - 1].provider.rawValue, item.chain[c.stageB - 1].provider.rawValue].sorted()
                        return cProviders.joined(separator: ":") == key
                    }
                    if hasDisagreement {
                        entry.disagreements += 1
                    }
                    pairMap[key] = entry
                }
            }
        }

        let pairs = pairMap.map { key, val in
            ProviderPairStat(
                id: key,
                providerA: val.providerA,
                providerB: val.providerB,
                totalPairings: val.totalPairings,
                disagreements: val.disagreements
            )
        }

        return (totalVerifications, averageConfidence, pairs)
    }
}
