import Foundation

enum ComplexityTier {
    case brief
    case moderate
    case detailed
}

struct LengthConfig {
    let tier: ComplexityTier
    let maxTokens: Int
    let promptInstruction: String
    let verifyInstruction: String
    let finalInstruction: String
}

enum QueryComplexityClassifier {
    static func classify(_ query: String) -> LengthConfig {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        let wordCount = words.count
        let lower = trimmed.lowercased()

        var score = 0

        // Word count
        if wordCount >= 9, wordCount <= 25 {
            score += 1
        } else if wordCount >= 26, wordCount <= 50 {
            score += 2
        } else if wordCount > 50 {
            score += 3
        }

        // Multiple question marks
        let questionMarks = query.filter { $0 == "?" }.count
        if questionMarks >= 2 {
            score += 2
        }

        // Multi-part connectors
        let multiPartPattern = /and also|additionally|furthermore|moreover/
        let numberedListPattern = /\d+\.\s/
        if lower.contains(multiPartPattern) ||
            trimmed.contains(numberedListPattern) ||
            trimmed.contains(";") {
            score += 2
        }

        // Depth keywords (cap at +2)
        let depthKeywords = [
            "explain", "analyze", "analyse", "compare", "contrast",
            "discuss", "step by step", "in detail", "elaborate", "comprehensive"
        ]
        var depthHits = 0
        for keyword in depthKeywords {
            if lower.contains(keyword) { depthHits += 1 }
        }
        score += min(depthHits, 2)

        // Simplicity keywords
        let simplicityPatterns = [
            "what is", "what's", "define", "who is", "who's",
            "yes or no", "true or false"
        ]
        for pattern in simplicityPatterns {
            if lower.contains(pattern) {
                score -= 2
                break
            }
        }

        if score <= 0 {
            return LengthConfig(
                tier: .brief,
                maxTokens: 512,
                promptInstruction: "Respond concisely. A few sentences is ideal.",
                verifyInstruction: "Keep your verification concise. Only flag real issues.",
                finalInstruction: "Synthesize into a brief, direct answer."
            )
        }
        if score <= 3 {
            return LengthConfig(
                tier: .moderate,
                maxTokens: 1536,
                promptInstruction: "Cover key points without excessive elaboration.",
                verifyInstruction: "Verify key claims. Be thorough but not verbose.",
                finalInstruction: "Produce a clear, well-structured answer covering the key points."
            )
        }
        return LengthConfig(
            tier: .detailed,
            maxTokens: 3072,
            promptInstruction: "Be thorough and comprehensive. Cover all aspects in depth.",
            verifyInstruction: "Conduct a thorough verification. Check every claim and add missing detail.",
            finalInstruction: "Produce a comprehensive, detailed synthesis covering all aspects in depth."
        )
    }
}
