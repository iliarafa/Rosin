import Foundation

enum StagePromptBuilder {
    static func systemPrompt(stageNumber: Int, isLast: Bool, lengthConfig: LengthConfig, adversarialMode: Bool = false) -> String {
        if stageNumber == 1 {
            return """
            You are the first stage of a multi-LLM verification pipeline. \
            Your task is to provide an initial, thorough response to the user's query. \
            Focus on accuracy and comprehensive coverage of the topic.

            Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.

            \(lengthConfig.promptInstruction)
            """
        }

        if isLast {
            return """
            You are the final stage of a multi-LLM verification pipeline. \
            You produce the definitive, verified response.

            Your tasks:
            1. Review all prior stage outputs for agreement and disagreement
            2. Where stages disagreed, state the most well-supported conclusion
            3. Synthesize all previous stages into a clear, concise final answer
            4. Remove any redundancy
            5. Ensure the response is well-structured and easy to understand
            6. Note any remaining caveats or areas of genuine uncertainty

            Produce the final verified response that best answers the user's original query.

            \(lengthConfig.finalInstruction)
            """
        }

        if adversarialMode {
            return """
            You are in ADVERSARIAL MODE. You are stage \(stageNumber) of a multi-LLM verification pipeline. \
            Your job is to find flaws.

            Your tasks:
            1. Actively search for errors and weak claims in the previous response
            2. Challenge every assumption \u{2014} demand evidence
            3. Identify hallucinations and fabricated details
            4. Cross-check facts rigorously against your knowledge
            5. Flag misleading, vague, or unsubstantiated information
            6. Provide a corrected and hardened version of the response

            Be aggressive in your analysis. Do not give the benefit of the doubt.

            \(lengthConfig.verifyInstruction)
            """
        }

        return """
        You are stage \(stageNumber) of a multi-LLM verification pipeline. \
        You are cross-checking all previous outputs.

        Your tasks:
        1. Verify the factual accuracy of the previous responses
        2. Compare outputs from all prior stages for consistency
        3. Identify any potential errors, hallucinations, or unsupported claims
        4. Correct any inaccuracies you find
        5. Add any important information that was missed
        6. Cross-check the information against your knowledge
        7. Improve clarity where needed

        Provide a refined and verified version of the response.

        \(lengthConfig.verifyInstruction)
        """
    }

    static func userContent(
        query: String,
        allPriorOutputs: [(stage: Int, model: LLMModel, content: String)]
    ) -> String {
        if allPriorOutputs.isEmpty {
            return "Original Query: \(query)"
        }

        var sections = "Original Query: \(query)\n"
        for prior in allPriorOutputs {
            sections += "\n\u{2500}\u{2500} Stage \(prior.stage) (\(prior.model.provider.shortName) / \(prior.model.model)) \u{2500}\u{2500}\n"
            sections += prior.content
            sections += "\n"
        }
        return sections
    }
}
