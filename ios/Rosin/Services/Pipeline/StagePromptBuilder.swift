import Foundation

enum StagePromptBuilder {
    static func systemPrompt(stageNumber: Int, isLast: Bool, lengthConfig: LengthConfig, adversarialMode: Bool = false, hasWebResearch: Bool = false, isSingleStage: Bool = false) -> String {
        if stageNumber == 1 && isSingleStage {
            let webDirective = hasWebResearch ? """


            IMPORTANT: You have been provided with live web search results alongside the user's query. \
            These results contain current, real-time information retrieved just now. You MUST:
            - Use the web search results as your primary source for current events, recent developments, and time-sensitive information
            - Cite sources by their number (e.g. [1], [2]) when referencing information from the search results
            - Do NOT disclaim knowledge cutoffs or say you lack access to current information — the search results ARE your access to current information
            - If the search results conflict with your training data, prefer the search results as they are more recent
            """ : ""
            return """
            You are an expert AI assistant. \
            Provide a thorough, accurate, and well-structured response to the user's query. \
            Focus on factual accuracy and comprehensive coverage of the topic.

            Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.\(webDirective)

            \(lengthConfig.promptInstruction)
            """
        }

        if stageNumber == 1 {
            let webDirective = hasWebResearch ? """


            IMPORTANT: You have been provided with live web search results alongside the user's query. \
            These results contain current, real-time information retrieved just now. You MUST:
            - Use the web search results as your primary source for current events, recent developments, and time-sensitive information
            - Cite sources by their number (e.g. [1], [2]) when referencing information from the search results
            - Do NOT disclaim knowledge cutoffs or say you lack access to current information — the search results ARE your access to current information
            - If the search results conflict with your training data, prefer the search results as they are more recent
            """ : ""
            return """
            You are the first stage of a multi-LLM verification pipeline. \
            Your task is to provide an initial, thorough response to the user's query. \
            Focus on accuracy and comprehensive coverage of the topic.

            Be factual and cite any assumptions you make. If you're uncertain about something, acknowledge it.\(webDirective)

            \(lengthConfig.promptInstruction)
            """
        }

        let webGroundingNote = hasWebResearch ? """

        Note: The first stage was provided with live web search results. \
        Information about current events and recent developments in the previous response \
        is grounded in real-time web data — treat it as sourced information, not speculation. \
        Do not dismiss it as beyond your knowledge cutoff.
        """ : ""

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

            Produce the final verified response that best answers the user's original query.\(webGroundingNote)

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

            Be aggressive in your analysis. Do not give the benefit of the doubt.\(webGroundingNote)

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

        Provide a refined and verified version of the response.\(webGroundingNote)

        \(lengthConfig.verifyInstruction)
        """
    }

    static func userContent(
        query: String,
        allPriorOutputs: [(stage: Int, model: LLMModel, content: String)],
        searchContext: String = ""
    ) -> String {
        if allPriorOutputs.isEmpty {
            if !searchContext.isEmpty {
                return "Original Query: \(query)\n\n\u{2500}\u{2500} Live Web Research \u{2500}\u{2500}\n\(searchContext)"
            }
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
