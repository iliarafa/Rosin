import Foundation

enum ResearchStatus {
    case searching
    case complete(sourceCount: Int, sources: String)
    case error(String)
}
