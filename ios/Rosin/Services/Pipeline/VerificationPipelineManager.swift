import Foundation

enum PipelineError: Error {
    case finalStageFailed(String)
}

@MainActor
final class VerificationPipelineManager {
    private let apiKeyManager: APIKeyManager
    private var currentTask: Task<Void, Never>?

    init(apiKeyManager: APIKeyManager) {
        self.apiKeyManager = apiKeyManager
    }

    var isRunning: Bool {
        currentTask != nil && currentTask?.isCancelled == false
    }

    func run(
        query: String,
        chain: [LLMModel],
        adversarialMode: Bool = false,
        liveResearch: Bool = false,
        autoTieBreaker: Bool = true,
        onEvent: @escaping (PipelineEvent) -> Void
    ) {
        cancel()

        currentTask = Task {
            var completedStages: [(stage: Int, model: LLMModel, content: String)] = []
            let totalStages = chain.count
            let lengthConfig = QueryComplexityClassifier.classify(query)

            // Live Research: prefer Exa.ai (neural search), fall back to Tavily
            var searchContext = ""
            if liveResearch {
                if let exaKey = apiKeyManager.exaKey {
                    onEvent(.researchStart)
                    do {
                        let searchResponse = try await ExaSearchService.search(query: query, apiKey: exaKey)
                        searchContext = searchResponse.formattedContext
                        onEvent(.researchComplete(
                            sourceCount: searchResponse.results.count,
                            sources: searchResponse.sourceSummary
                        ))
                    } catch {
                        NSLog("[Pipeline] Exa search failed, falling back to Tavily: %@", "\(error)")
                        // Fall through to Tavily
                        if let tavilyKey = apiKeyManager.tavilyKey {
                            do {
                                let searchResponse = try await TavilySearchService.search(query: query, apiKey: tavilyKey)
                                searchContext = searchResponse.formattedContext
                                onEvent(.researchComplete(
                                    sourceCount: searchResponse.results.count,
                                    sources: searchResponse.sourceSummary
                                ))
                            } catch {
                                onEvent(.researchError(error: "Web search failed — proceeding without live data"))
                            }
                        } else {
                            onEvent(.researchError(error: "Exa search failed and no Tavily key configured"))
                        }
                    }
                } else if let tavilyKey = apiKeyManager.tavilyKey {
                    onEvent(.researchStart)
                    do {
                        let searchResponse = try await TavilySearchService.search(query: query, apiKey: tavilyKey)
                        searchContext = searchResponse.formattedContext
                        onEvent(.researchComplete(
                            sourceCount: searchResponse.results.count,
                            sources: searchResponse.sourceSummary
                        ))
                    } catch {
                        onEvent(.researchError(error: "Web search failed — proceeding without live data"))
                    }
                } else {
                    onEvent(.researchError(error: "No search API key configured — add Exa or Tavily key in Settings"))
                }
            }

            let hasWebResearch = !searchContext.isEmpty

            do {
                for (index, llmModel) in chain.enumerated() {
                    if Task.isCancelled { return }

                    let stageNum = index + 1
                    let isLast = index == totalStages - 1

                    let result = try await executeStageWithResilience(
                        stageNum: stageNum,
                        primaryModel: llmModel,
                        isLast: isLast,
                        query: query,
                        completedStages: completedStages,
                        totalStages: totalStages,
                        lengthConfig: lengthConfig,
                        adversarialMode: adversarialMode,
                        hasWebResearch: hasWebResearch,
                        searchContext: searchContext,
                        onEvent: onEvent
                    )

                    if let result {
                        completedStages.append((stage: stageNum, model: result.model, content: result.content))
                    }
                    // nil means skipped — pipeline continues
                }
            } catch {
                // Only thrown for final stage failure
                if Task.isCancelled { return }
                if let pipelineError = error as? PipelineError,
                   case .finalStageFailed(let msg) = pipelineError {
                    onEvent(.stageError(stage: totalStages, error: msg))
                }
                onEvent(.done)
                currentTask = nil
                return
            }

            if Task.isCancelled { return }

            // ── Judge Stage ──
            // Run the dedicated Judge to produce structured per-stage analysis + overall verdict
            var summary = await runJudge(
                query: query,
                completedStages: completedStages,
                totalStages: totalStages,
                liveResearchUsed: hasWebResearch,
                searchContext: searchContext,
                onEvent: onEvent
            )

            // ── Auto Tie-Breaker ──
            // If the Judge detects strong disagreement, run an extra verification stage
            // to resolve conflicts before finalizing the result.
            if autoTieBreaker, let jv = summary.judgeVerdict {
                let tieBreak = Self.shouldTriggerTieBreaker(jv)
                if tieBreak.triggered, !Task.isCancelled {
                    onEvent(.tieBreaker(reason: tieBreak.reason))

                    let tbStageNum = totalStages + 1
                    let tbModel = pickTieBreakerModel()

                    if let tbModel {
                        let tbResult = try? await executeStageWithResilience(
                            stageNum: tbStageNum,
                            primaryModel: tbModel,
                            isLast: true,
                            query: query,
                            completedStages: completedStages,
                            totalStages: tbStageNum,
                            lengthConfig: lengthConfig,
                            adversarialMode: false,
                            hasWebResearch: hasWebResearch,
                            searchContext: "",
                            onEvent: onEvent,
                            tieBreakerVerdict: jv
                        )

                        if let tbResult {
                            completedStages.append((stage: tbStageNum, model: tbResult.model, content: tbResult.content))

                            // Re-run Judge with expanded stage set
                            if !Task.isCancelled {
                                summary = await runJudge(
                                    query: query,
                                    completedStages: completedStages,
                                    totalStages: completedStages.count,
                                    liveResearchUsed: hasWebResearch,
                                    searchContext: searchContext,
                                    onEvent: onEvent
                                )
                            }
                        }
                    }
                }
            }

            onEvent(.summary(summary))
            onEvent(.done)
            currentTask = nil
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Tie-Breaker Logic

    /// Determine if the Tie-Breaker stage should run based on Judge verdict.
    /// Triggers when:
    ///   1. Score variance between stages > 25 points (strong disagreement)
    ///   2. Overall Judge score < 50 (low confidence)
    ///   3. >= 2 "flagged" or "corrected" provenance entries (significant corrections)
    static func shouldTriggerTieBreaker(_ verdict: JudgeVerdict) -> (triggered: Bool, reason: String) {
        guard verdict.stageAnalyses.count >= 2 else { return (false, "") }

        let scores = verdict.stageAnalyses.map { $0.agreementScore }
        let scoreVariance = (scores.max() ?? 0) - (scores.min() ?? 0) > 25

        let lowConfidence = verdict.overallScore < 50

        let flaggedOrCorrected = verdict.stageAnalyses.flatMap { sa in
            sa.claims.flatMap { claim in
                (claim.provenance ?? []).filter { $0.changeType == .flagged || $0.changeType == .corrected }
            }
        }.count
        let hasManyFlags = flaggedOrCorrected >= 2

        var reasons: [String] = []
        if scoreVariance { reasons.append("stage score variance > 25pts") }
        if lowConfidence { reasons.append("overall score \(verdict.overallScore)/100") }
        if hasManyFlags { reasons.append("\(flaggedOrCorrected) flagged/corrected claims") }

        return (scoreVariance || lowConfidence || hasManyFlags, reasons.joined(separator: ", "))
    }

    /// Pick the strongest available model for the tie-breaker stage (same logic as Judge).
    private func pickTieBreakerModel() -> LLMModel? {
        let candidates: [(provider: LLMProvider, model: String)] = [
            (.anthropic, "claude-sonnet-4-5"),
            (.gemini, "gemini-2.5-flash"),
            (.xai, "grok-3"),
        ]
        for candidate in candidates {
            if apiKeyManager.apiKey(for: candidate.provider) != nil {
                return LLMModel(provider: candidate.provider, model: candidate.model)
            }
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Runs a single LLM call, streaming content chunks to the UI.
    /// Returns the accumulated content, or nil on any error.
    /// Does NOT emit stageStart/stageComplete/stageError — the caller manages those.
    private func attemptStage(
        stageNum: Int,
        model: LLMModel,
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        lengthConfig: LengthConfig,
        adversarialMode: Bool = false,
        hasWebResearch: Bool = false,
        searchContext: String = "",
        onEvent: @escaping (PipelineEvent) -> Void,
        tieBreakerVerdict: JudgeVerdict? = nil
    ) async -> String? {
        guard let apiKey = apiKeyManager.apiKey(for: model.provider) else {
            return nil
        }

        let systemPrompt: String
        let userContent: String

        if let verdict = tieBreakerVerdict {
            // Tie-breaker stage: use special prompt with Judge context
            systemPrompt = StagePromptBuilder.tieBreakerPrompt(lengthConfig: lengthConfig)
            userContent = StagePromptBuilder.tieBreakerUserContent(
                query: query,
                allPriorOutputs: completedStages,
                judgeVerdict: verdict,
                searchContext: searchContext
            )
        } else {
            let isLast = stageNum == totalStages
            systemPrompt = StagePromptBuilder.systemPrompt(
                stageNumber: stageNum,
                isLast: isLast,
                lengthConfig: lengthConfig,
                adversarialMode: adversarialMode,
                hasWebResearch: hasWebResearch,
                isSingleStage: totalStages == 1
            )
            // Every stage gets the Tavily results so each model can independently
            // verify claims against fresh web sources, not just training data.
            userContent = StagePromptBuilder.userContent(
                query: query,
                allPriorOutputs: completedStages,
                searchContext: searchContext
            )
        }

        let service = LLMServiceFactory.service(for: model.provider)
        let stream = service.streamCompletion(
            model: model.model,
            systemPrompt: systemPrompt,
            userContent: userContent,
            apiKey: apiKey,
            maxTokens: lengthConfig.maxTokens
        )

        var stageContent = ""
        do {
            for try await text in stream {
                if Task.isCancelled { return nil }
                stageContent += text
                onEvent(.content(stage: stageNum, text: text))
            }
            return stageContent
        } catch {
            if Task.isCancelled { return nil }
            return nil
        }
    }

    /// Executes a stage with up to 3 attempts: primary, retry same model, fallback model.
    /// Returns the content and model used, or nil if skipped (non-final stage).
    /// Throws PipelineError.finalStageFailed if all attempts fail on the final stage.
    private func executeStageWithResilience(
        stageNum: Int,
        primaryModel: LLMModel,
        isLast: Bool,
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        lengthConfig: LengthConfig,
        adversarialMode: Bool = false,
        hasWebResearch: Bool = false,
        searchContext: String = "",
        onEvent: @escaping (PipelineEvent) -> Void,
        tieBreakerVerdict: JudgeVerdict? = nil
    ) async throws -> (content: String, model: LLMModel)? {
        // Emit stageStart once before first attempt
        onEvent(.stageStart(stage: stageNum, model: primaryModel))

        // Attempt 1: primary model
        if let content = await attemptStage(
            stageNum: stageNum,
            model: primaryModel,
            query: query,
            completedStages: completedStages,
            totalStages: totalStages,
            lengthConfig: lengthConfig,
            adversarialMode: adversarialMode,
            hasWebResearch: hasWebResearch,
            searchContext: searchContext,
            onEvent: onEvent,
            tieBreakerVerdict: tieBreakerVerdict
        ) {
            onEvent(.stageComplete(stage: stageNum))
            return (content: content, model: primaryModel)
        }

        if Task.isCancelled { return nil }

        // Attempt 2: retry same model
        onEvent(.stageRetry(stage: stageNum, model: primaryModel, attempt: 2))

        if let content = await attemptStage(
            stageNum: stageNum,
            model: primaryModel,
            query: query,
            completedStages: completedStages,
            totalStages: totalStages,
            lengthConfig: lengthConfig,
            adversarialMode: adversarialMode,
            hasWebResearch: hasWebResearch,
            searchContext: searchContext,
            onEvent: onEvent,
            tieBreakerVerdict: tieBreakerVerdict
        ) {
            onEvent(.stageComplete(stage: stageNum))
            return (content: content, model: primaryModel)
        }

        if Task.isCancelled { return nil }

        // Attempt 3: fallback model from a different provider
        if let fallback = LLMServiceFactory.fallbackModel(
            excluding: primaryModel.provider,
            apiKeyManager: apiKeyManager
        ) {
            onEvent(.stageRetry(stage: stageNum, model: fallback, attempt: 3))

            if let content = await attemptStage(
                stageNum: stageNum,
                model: fallback,
                query: query,
                completedStages: completedStages,
                totalStages: totalStages,
                lengthConfig: lengthConfig,
                adversarialMode: adversarialMode,
                hasWebResearch: hasWebResearch,
                searchContext: searchContext,
                onEvent: onEvent
            ) {
                onEvent(.stageComplete(stage: stageNum))
                return (content: content, model: fallback)
            }
        }

        if Task.isCancelled { return nil }

        // All attempts failed
        if isLast {
            throw PipelineError.finalStageFailed(
                "All attempts failed for final stage \(stageNum). Verification incomplete."
            )
        }

        onEvent(.stageSkipped(stage: stageNum, error: "All attempts failed — stage skipped"))
        return nil
    }

    // MARK: - Judge Stage
    // The Judge is a dedicated analysis stage that runs after all verification stages.
    // It produces a comprehensive structured verdict (JudgeVerdict) with per-stage
    // agreement scores, claim extraction, hallucination flags, and overall scoring.
    // The Judge output is decoded as JudgeVerdict and used to build the VerificationSummary.

    /// Pick the strongest available model for the Judge call
    private func pickJudgeModel() -> (model: LLMModel, apiKey: String)? {
        // Prefer strong models — the Judge needs the best reasoning
        let candidates: [(provider: LLMProvider, model: String)] = [
            (.anthropic, "claude-sonnet-4-5"),
            (.gemini, "gemini-2.5-flash"),
            (.xai, "grok-3"),
        ]
        for candidate in candidates {
            if let key = apiKeyManager.apiKey(for: candidate.provider) {
                return (LLMModel(provider: candidate.provider, model: candidate.model), key)
            }
        }
        return nil
    }

    /// Parse raw LLM text as JSON, stripping markdown fences if needed
    private func parseJudgeJSON(_ text: String) -> Data? {
        if let data = text.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) {
            return data
        }
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.data(using: .utf8)
    }

    func runJudge(
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        liveResearchUsed: Bool = false,
        searchContext: String = "",
        onEvent: @escaping (PipelineEvent) -> Void
    ) async -> VerificationSummary {
        guard !completedStages.isEmpty else {
            NSLog("[Judge] No completed stages — using fallback summary")
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        guard let judgeConfig = pickJudgeModel() else {
            NSLog("[Judge] No API key available for Judge model — using fallback summary")
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }
        NSLog("[Judge] Using %@ for Judge analysis", judgeConfig.model.model)

        // Build the stage outputs text for the Judge
        let modelNames = completedStages.map { "\($0.model.provider.shortName) (\($0.model.model))" }.joined(separator: ", ")
        let liveResearchNote = liveResearchUsed ? " Live web research (Tavily) was used to ground Stage 1 with real-time data." : ""

        // Cap each stage's content to ~4000 chars to keep Judge input within model context limits.
        // With 4 stages at 4000 chars each + prompt, total input stays well under 128K tokens.
        let maxStageChars = 4000
        var stageOutputsText = ""
        for stage in completedStages {
            stageOutputsText += "── Stage \(stage.stage) (\(stage.model.provider.shortName) / \(stage.model.model)) ──\n"
            if stage.content.count > maxStageChars {
                stageOutputsText += String(stage.content.prefix(maxStageChars))
                stageOutputsText += "\n[... truncated for Judge analysis]\n"
            } else {
                stageOutputsText += stage.content
            }
            stageOutputsText += "\n\n"
        }
        NSLog("[Judge] Input: %d stages, ~%d chars total", completedStages.count, stageOutputsText.count)

        // The Judge prompt requests the full JudgeVerdict JSON structure
        let systemPrompt = """
        You are the final JUDGE in Rosin AI's multi-LLM verification pipeline. \
        The models used were: \(modelNames).\(liveResearchNote)

        Your job is to synthesize all previous stages and produce a truthful, well-calibrated final verdict.

        CONSENSUS RULE (HIGHEST PRIORITY):
        - When ALL or MOST stages agree on a claim (especially about a product's existence, specs, or pricing), \
        you MUST heavily favor that consensus. Do NOT override multi-stage agreement with your own skepticism.
        - You may ONLY override strong stage consensus when you have clear, specific contradictory evidence from \
        high-credibility sources (apple.com, official press releases, MacRumors, The Verge, etc.).
        - If you do override consensus, you MUST explain exactly why with specific evidence. \
        "I don't recognize this product" is NOT valid evidence.

        NEW/RECENT PRODUCTS (within last 60 days):
        - Recent web search results + stage consensus are MORE reliable than your training data.
        - Only declare a product "does not exist" when there is overwhelming evidence: zero official presence \
        on apple.com, no press releases, no credible journalism. Noisy or speculative sources are NOT sufficient grounds.
        - When Live Research was used, treat the provided Tavily results as primary evidence.

        CONFIDENCE RULES:
        - confidence MUST be consistent with overallScore: "high" (score >= 80), "moderate" (50-79), "low" (< 50).
        - NEVER output a low score with "high" confidence or vice versa.

        Always prioritize truth and evidence over forced skepticism.

        Respond with ONLY valid JSON (no markdown, no code fences):
        {
          "verdict": "2-3 sentence expert verdict summarizing the verification result, referencing the actual topic",
          "overallScore": 87,
          "confidence": "high",
          "keyFindings": [
            "Finding 1 \u{2014} topic-specific, referencing models by short name (Claude/Gemini/Grok)",
            "Finding 2 \u{2014} note consensus or disagreements between specific models",
            "Finding 3 \u{2014} confidence justification tied to the query content",
            "Finding 4 \u{2014} mention live web research if used, or note data currency"
          ],
          "stageAnalyses": [
            {
              "stage": 1,
              "agreementScore": 92,
              "claims": [
                {
                  "text": "Key claim extracted from this stage",
                  "confidence": 85,
                  "sources": [],
                  "provenance": [
                    {
                      "model": "Claude",
                      "stage": 1,
                      "changeType": "added",
                      "newText": "Key claim as first introduced",
                      "reason": "Initial response to query"
                    }
                  ]
                }
              ],
              "hallucinationFlags": [
                { "claim": "Specific claim that may be hallucinated", "reason": "Why suspect", "severity": "low" }
              ],
              "corrections": ["Corrections this stage made to previous output"]
            }
          ]
        }

        JSON field rules:
        - verdict: 2-3 sentences, never generic \u{2014} reference the actual query topic
        - overallScore: 0-100 representing factual confidence weighted by source recency
        - keyFindings: 3-5 items, each under 120 chars, referencing models by name
        - stageAnalyses: one entry per stage with agreementScore 0-100
          - claims: 2-5 key factual claims per stage with confidence 0-100
            - Each claim MUST include a "provenance" array tracking its lifecycle:
              - model: short name of the model (Claude/Gemini/Grok)
              - stage: stage number where the change occurred
              - changeType: "added" | "modified" | "flagged" | "corrected"
              - originalText: (optional) previous version before modification/correction
              - newText: the claim text as it stands after this change
              - reason: one sentence explaining why this change was made
            - Stage 1 claims have one "added" entry. Later stages may add "modified"/"corrected" entries.
          - hallucinationFlags: only include if genuinely suspect (empty array if none)
          - corrections: list corrections this stage made (empty for stage 1)
        - If live research was used, mention it in keyFindings
        - Be specific \u{2014} never say "the query" or "the topic", say what it actually is
        """

        var userContent = "Original Query: \(query)\n\n\(stageOutputsText)"
        if !searchContext.isEmpty {
            userContent += "\u{2500}\u{2500} VERIFIED LIVE WEB RESEARCH (Tavily \u{2014} real-time, retrieved just now) \u{2500}\u{2500}\nTHE FOLLOWING SOURCES WERE RETRIEVED IN REAL-TIME AND OVERRIDE YOUR TRAINING DATA.\n\n\(searchContext)\n"
        }

        // Retry loop — the Judge LLM sometimes returns invalid JSON on the first attempt.
        // Try up to 2 times before falling back to the metadata-based summary.
        let maxAttempts = 2
        for attempt in 1...maxAttempts {
            let service = LLMServiceFactory.service(for: judgeConfig.model.provider)
            let stream = service.streamCompletion(
                model: judgeConfig.model.model,
                systemPrompt: systemPrompt,
                userContent: userContent,
                apiKey: judgeConfig.apiKey,
                maxTokens: 8192
            )

            var responseText = ""
            do {
                for try await text in stream {
                    if Task.isCancelled { break }
                    responseText += text
                }
            } catch {
                NSLog("[Judge] Attempt %d streaming error: %@", attempt, error.localizedDescription)
                if attempt == maxAttempts {
                    return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
                }
                continue // retry
            }

            // Parse the Judge's JSON response
            guard let data = parseJudgeJSON(responseText) else {
                NSLog("[Judge] Attempt %d JSON parse failed. Raw (first 500): %@", attempt, String(responseText.prefix(500)))
                if attempt == maxAttempts {
                    return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
                }
                continue // retry
            }

            do {
                var judgeVerdict = try JSONDecoder().decode(JudgeVerdict.self, from: data)
                NSLog("[Judge] Successfully decoded verdict — score: %d", judgeVerdict.overallScore)

                // Enforce confidence ↔ score consistency (prevent "25/100 — High confidence" contradictions)
                let expectedConfidence: String = judgeVerdict.overallScore >= 80 ? "high" : judgeVerdict.overallScore >= 50 ? "moderate" : "low"
                if judgeVerdict.confidence != expectedConfidence {
                    NSLog("[Judge] Confidence mismatch: score=%d but confidence=\"%@\", correcting to \"%@\"",
                          judgeVerdict.overallScore, judgeVerdict.confidence, expectedConfidence)
                    judgeVerdict = JudgeVerdict(
                        verdict: judgeVerdict.verdict,
                        overallScore: judgeVerdict.overallScore,
                        confidence: expectedConfidence,
                        keyFindings: judgeVerdict.keyFindings,
                        stageAnalyses: judgeVerdict.stageAnalyses
                    )
                }

                // Emit per-stage analysis events so the ViewModel can attach scores to stages
                for sa in judgeVerdict.stageAnalyses {
                    onEvent(.stageAnalysis(stage: sa.stage, analysis: sa))
                }

                // Build VerificationSummary from the Judge verdict
                let confidenceScore = Double(judgeVerdict.overallScore) / 100.0
                let confidenceText = "\(judgeVerdict.confidence.capitalized) (\(judgeVerdict.overallScore)%)"

                let contradictions = judgeVerdict.stageAnalyses.flatMap { sa in
                    sa.hallucinationFlags
                        .filter { $0.severity == .high }
                        .map { flag in
                            Contradiction(
                                topic: flag.claim,
                                stageA: sa.stage,
                                stageB: 0,
                                description: flag.reason
                            )
                        }
                }

                let totalFlags = judgeVerdict.stageAnalyses.reduce(0) { $0 + $1.hallucinationFlags.count }
                let hallucinationText: String
                if totalFlags == 0 {
                    hallucinationText = "No hallucinations detected across any stage"
                } else {
                    let flaggedStages = judgeVerdict.stageAnalyses.filter { !$0.hallucinationFlags.isEmpty }.count
                    hallucinationText = "\(totalFlags) potential issue\(totalFlags > 1 ? "s" : "") flagged across \(flaggedStages) stage\(flaggedStages > 1 ? "s" : "")"
                }

                let avgAgreement = judgeVerdict.stageAnalyses.isEmpty ? 0 :
                    judgeVerdict.stageAnalyses.reduce(0) { $0 + $1.agreementScore } / judgeVerdict.stageAnalyses.count
                let consistencyText = "\(avgAgreement)% average agreement across \(completedStages.count) stage\(completedStages.count == 1 ? "" : "s")"

                return VerificationSummary(
                    consistency: consistencyText,
                    hallucinations: hallucinationText,
                    confidence: confidenceText,
                    contradictions: contradictions,
                    confidenceScore: confidenceScore,
                    isAnalyzed: true,
                    analysisBullets: judgeVerdict.keyFindings,
                    judgeVerdict: judgeVerdict
                )
            } catch {
                NSLog("[Judge] Attempt %d decode error: %@", attempt, String(describing: error))
                if attempt == maxAttempts {
                    return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
                }
                // retry on next iteration
            }
        }

        // Should never reach here, but safety net
        return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
    }

    /// Generates a contextual fallback summary using pipeline metadata when the Judge is unavailable.
    func fallbackSummary(
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        liveResearchUsed: Bool = false
    ) -> VerificationSummary {
        let completed = completedStages.count
        let skipped = totalStages - completed

        let consistency: String
        if completed < 2 {
            consistency = "Insufficient stages for cross-verification"
        } else if skipped > 0 {
            consistency = "Cross-verified across \(completed) of \(totalStages) LLMs (\(skipped) skipped)"
        } else {
            consistency = "Cross-verified across \(completed) independent LLMs"
        }

        let confidence: String
        if completed >= 3 {
            confidence = "High \u{2013} multi-stage verification complete"
        } else if completed == 2 {
            confidence = "Moderate \u{2013} dual verification complete"
        } else {
            confidence = "Low \u{2013} single-stage only"
        }

        let hallucinations: String
        if skipped > 0 {
            hallucinations = "Checked at \(completed) of \(totalStages) stages \u{2013} coverage reduced"
        } else {
            hallucinations = "Checked at each stage \u{2013} potential issues flagged"
        }

        let bullets = Self.buildFallbackBullets(
            query: query,
            completedStages: completedStages,
            totalStages: totalStages,
            liveResearchUsed: liveResearchUsed
        )

        return VerificationSummary(
            consistency: consistency,
            hallucinations: hallucinations,
            confidence: confidence,
            contradictions: [],
            confidenceScore: nil,
            isAnalyzed: false,
            analysisBullets: bullets
        )
    }

    /// Builds contextual bullet points from pipeline metadata when the Judge is unavailable.
    private static func buildFallbackBullets(
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        liveResearchUsed: Bool
    ) -> [String] {
        var bullets: [String] = []

        let topicSnippet: String = {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count <= 60 { return trimmed }
            let prefix = String(trimmed.prefix(60))
            if let lastSpace = prefix.lastIndex(of: " ") {
                return String(prefix[prefix.startIndex..<lastSpace]) + "…"
            }
            return prefix + "…"
        }()

        let modelShortNames = completedStages.map { $0.model.provider.shortName }
        let uniqueNames = NSOrderedSet(array: modelShortNames).array as! [String]
        bullets.append("Queried \"\(topicSnippet)\" through \(uniqueNames.joined(separator: ", "))")

        let completed = completedStages.count
        if completed == totalStages {
            bullets.append(completed == 1 ? "Single-stage completion — no cross-verification" : "All \(completed) verification stages completed successfully")
        } else {
            bullets.append("\(completed) of \(totalStages) stages completed — partial coverage")
        }

        if liveResearchUsed {
            bullets.append("Grounded with live web data via Tavily search")
        } else {
            bullets.append("Based on model training data — no live web sources used")
        }

        return bullets
    }
}
