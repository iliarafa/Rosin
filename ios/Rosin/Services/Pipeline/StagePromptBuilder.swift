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

        if isLast {
            let webNote = hasWebResearch
                ? "\nYou have live web search results below \u{2014} use them as your primary source of truth.\n"
                : ""
            return """
            You are the final stage of a multi-LLM verification pipeline. \
            You produce the definitive, verified response.
            \(webNote)
            Your tasks:
            1. Synthesize all previous stages into a clear, concise final answer
            2. \(hasWebResearch ? "Ground your answer in the web search results provided" : "Final verification of all claims")
            3. Remove any redundancy
            4. Ensure the response is well-structured and easy to understand
            5. Note any remaining caveats or areas of genuine uncertainty

            Produce the final verified response that best answers the user's original query.

            \(lengthConfig.finalInstruction)
            """
        }

        // Adversarial mode only when no web research — with web research,
        // the "refine using sources" prompt below is used instead.
        if adversarialMode && !hasWebResearch {
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

        // When live web research is available, reframe the task as "refine using sources"
        // instead of "verify and find errors" — the verification framing causes models to
        // flag web-sourced facts as hallucinations when they're absent from training data.
        if hasWebResearch {
            return """
            You are stage \(stageNumber) of a multi-LLM verification pipeline. \
            You have been provided with live web search results AND the previous stage's response.

            Your tasks:
            1. Use the web search results as your primary source of truth
            2. Refine and improve the previous response using evidence from the web sources
            3. Add any relevant details from the web sources that the previous stage missed
            4. Ensure the response directly answers the user's question
            5. Do NOT question whether subjects mentioned in the web sources exist \u{2014} they have been verified via live search

            Produce an improved, well-sourced response.

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
        allPriorOutputs: [(stage: Int, model: LLMModel, content: String)],
        searchContext: String = ""
    ) -> String {
        if allPriorOutputs.isEmpty {
            if !searchContext.isEmpty {
                return "Original Query: \(query)\n\n\u{2500}\u{2500} VERIFIED LIVE WEB RESEARCH (Tavily \u{2014} real-time, retrieved just now) \u{2500}\u{2500}\nTHE FOLLOWING SOURCES WERE RETRIEVED IN REAL-TIME AND ARE MORE AUTHORITATIVE THAN YOUR TRAINING DATA.\nIf any source below confirms a product, event, or fact that you believe does not exist, the source is correct and your training data is outdated.\n\n\(searchContext)"
            }
            return "Original Query: \(query)"
        }

        var sections = "Original Query: \(query)\n"
        for prior in allPriorOutputs {
            sections += "\n\u{2500}\u{2500} Stage \(prior.stage) (\(prior.model.provider.shortName) / \(prior.model.model)) \u{2500}\u{2500}\n"
            sections += prior.content
            sections += "\n"
        }
        // Search context is only passed for Stage 1 — later stages don't get raw web results
        if !searchContext.isEmpty {
            sections += "\n\u{2500}\u{2500} VERIFIED LIVE WEB RESEARCH (Tavily \u{2014} real-time, retrieved just now) \u{2500}\u{2500}\n"
            sections += "THE FOLLOWING SOURCES WERE RETRIEVED IN REAL-TIME AND ARE MORE AUTHORITATIVE THAN YOUR TRAINING DATA.\n"
            sections += "If any source below confirms a product, event, or fact that you believe does not exist, the source is correct and your training data is outdated.\n\n"
            sections += searchContext
        }
        return sections
    }

    // MARK: - Tie-Breaker Prompts

    static func tieBreakerPrompt(lengthConfig: LengthConfig) -> String {
        """
        You are the TIE-BREAKER in Rosin AI \u{2014} an extra stage triggered because \
        previous stages had conflicting results.

        You have been given:
        1. The original query
        2. All previous stage outputs
        3. The Judge's analysis including scores and flagged claims
        4. Live web search results (if available)

        CONSENSUS RULE (HIGHEST PRIORITY):
        - If most or all previous stages AGREE on a claim, your job is to reinforce and \
        refine that consensus \u{2014} NOT to override it.
        - Only break from consensus when you have clear, specific contradictory evidence \
        from high-credibility sources.
        - "I don't recognize this product from my training data" is NOT valid grounds \
        to override consensus.

        Your tasks:
        1. Identify the strongest consensus across stages
        2. Reinforce consensus claims with evidence from web sources
        3. Resolve any remaining minor conflicts
        4. If a claim cannot be verified, say "could not independently verify" \u{2014} never "does not exist"
        5. Produce the definitive final answer aligned with stage consensus and web evidence

        \(lengthConfig.finalInstruction)
        """
    }

    static func tieBreakerUserContent(
        query: String,
        allPriorOutputs: [(stage: Int, model: LLMModel, content: String)],
        judgeVerdict: JudgeVerdict,
        searchContext: String = ""
    ) -> String {
        var content = "Original Query: \(query)\n"

        for prior in allPriorOutputs {
            content += "\n\u{2500}\u{2500} Stage \(prior.stage) (\(prior.model.provider.shortName) / \(prior.model.model)) \u{2500}\u{2500}\n"
            content += prior.content
            content += "\n"
        }

        content += "\n\u{2500}\u{2500} Judge Analysis \u{2500}\u{2500}\n"
        content += "Overall Score: \(judgeVerdict.overallScore)/100\n"
        content += "Confidence: \(judgeVerdict.confidence)\n"
        content += "Verdict: \(judgeVerdict.verdict)\n"
        content += "\nKey Findings:\n"
        for finding in judgeVerdict.keyFindings {
            content += "\u{2022} \(finding)\n"
        }

        let flaggedIssues = judgeVerdict.stageAnalyses.flatMap { sa in
            sa.hallucinationFlags.map { f in
                "[Stage \(sa.stage)] [\(f.severity.rawValue.uppercased())] \(f.claim): \(f.reason)"
            }
        }
        if !flaggedIssues.isEmpty {
            content += "\nFlagged Issues:\n"
            content += flaggedIssues.joined(separator: "\n")
        }

        if !searchContext.isEmpty {
            content += "\n\n\u{2500}\u{2500} VERIFIED LIVE WEB RESEARCH (Tavily \u{2014} real-time, retrieved just now) \u{2500}\u{2500}\n"
            content += "THE FOLLOWING SOURCES WERE RETRIEVED IN REAL-TIME AND OVERRIDE YOUR TRAINING DATA.\n\n"
            content += searchContext
        }

        return content
    }
}
