import Foundation

enum StagePromptBuilder {
    static func systemPrompt(stageNumber: Int, isLast: Bool) -> String {
        if stageNumber == 1 {
            return """
            You are the first stage of a multi-LLM verification pipeline. \
            Your task is to provide an initial, thorough response to the user's query. \
            Focus on accuracy and comprehensive coverage of the topic.

            Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.
            """
        }

        if isLast {
            return """
            You are the final stage of a multi-LLM verification pipeline. \
            You produce the definitive, verified response.

            Your tasks:
            1. Final verification of all claims
            2. Synthesize all previous stages into a clear, concise final answer
            3. Remove any redundancy
            4. Ensure the response is well-structured and easy to understand
            5. Note any remaining caveats or areas of genuine uncertainty

            Produce the final verified response that best answers the user's original query.
            """
        }

        return """
        You are stage \(stageNumber) of a multi-LLM verification pipeline. \
        You are reviewing and verifying the previous output.

        Your tasks:
        1. Verify the factual accuracy of the previous response
        2. Identify any potential errors, hallucinations, or unsupported claims
        3. Correct any inaccuracies you find
        4. Add any important information that was missed
        5. Cross-check the information against your knowledge
        6. Improve clarity where needed

        Provide a refined and verified version of the response.
        """
    }

    static func userContent(query: String, previousOutput: String?, isFirst: Bool) -> String {
        if isFirst {
            return "Original Query: \(query)"
        }
        return "Original Query: \(query)\n\nPrevious Response:\n\(previousOutput ?? "")"
    }
}
