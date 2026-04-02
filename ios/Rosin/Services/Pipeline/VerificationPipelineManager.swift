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
        onEvent: @escaping (PipelineEvent) -> Void
    ) {
        cancel()

        currentTask = Task {
            var completedStages: [(stage: Int, model: LLMModel, content: String)] = []
            let totalStages = chain.count
            let lengthConfig = QueryComplexityClassifier.classify(query)

            // Live Research: run Tavily search before the verification pipeline
            var searchContext = ""
            if liveResearch {
                if let tavilyKey = apiKeyManager.tavilyKey {
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
                    onEvent(.researchError(error: "Tavily API key not configured — add it in Settings"))
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
            // Skip Judge for single-stage runs — no cross-verification to analyze
            let summary: VerificationSummary
            if totalStages == 1 {
                summary = fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: hasWebResearch)
            } else {
                summary = await runJudge(
                    query: query,
                    completedStages: completedStages,
                    totalStages: totalStages,
                    liveResearchUsed: hasWebResearch,
                    onEvent: onEvent
                )
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
        onEvent: @escaping (PipelineEvent) -> Void
    ) async -> String? {
        guard let apiKey = apiKeyManager.apiKey(for: model.provider) else {
            return nil
        }

        let isLast = stageNum == totalStages
        let systemPrompt = StagePromptBuilder.systemPrompt(
            stageNumber: stageNum,
            isLast: isLast,
            lengthConfig: lengthConfig,
            adversarialMode: adversarialMode,
            hasWebResearch: hasWebResearch,
            isSingleStage: totalStages == 1
        )
        // Inject search context only into Stage 1
        let userContent = StagePromptBuilder.userContent(
            query: query,
            allPriorOutputs: completedStages,
            searchContext: stageNum == 1 ? searchContext : ""
        )

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
        onEvent: @escaping (PipelineEvent) -> Void
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
            onEvent: onEvent
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
            onEvent: onEvent
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
        onEvent: @escaping (PipelineEvent) -> Void
    ) async -> VerificationSummary {
        guard completedStages.count >= 2 else {
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        guard let judgeConfig = pickJudgeModel() else {
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        // Build the stage outputs text for the Judge
        let modelNames = completedStages.map { "\($0.model.provider.shortName) (\($0.model.model))" }.joined(separator: ", ")
        let liveResearchNote = liveResearchUsed ? " Live web research (Tavily) was used to ground Stage 1 with real-time data." : ""

        var stageOutputsText = ""
        for stage in completedStages {
            stageOutputsText += "── Stage \(stage.stage) (\(stage.model.provider.shortName) / \(stage.model.model)) ──\n"
            stageOutputsText += stage.content
            stageOutputsText += "\n\n"
        }

        // The Judge prompt requests the full JudgeVerdict JSON structure
        let systemPrompt = """
        You are the JUDGE — the final authority in a multi-LLM verification pipeline. \
        The models used were: \(modelNames).\(liveResearchNote)

        You will receive the original query and all stage outputs. Produce a comprehensive structured verdict.

        Respond with ONLY valid JSON (no markdown, no code fences):
        {
          "verdict": "2-3 sentence expert verdict summarizing the verification result, referencing the actual topic",
          "overallScore": 87,
          "confidence": "high",
          "keyFindings": [
            "Finding 1 — topic-specific, referencing models by short name (Claude/Gemini/Grok)",
            "Finding 2 — note consensus or disagreements between specific models",
            "Finding 3 — confidence justification tied to the query content",
            "Finding 4 — mention live web research if used, or note data currency"
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

        Rules:
        - verdict: 2-3 sentences, never generic — reference the actual query topic
        - overallScore: 0-100 representing cross-model agreement and factual confidence
        - confidence: "high" (score >= 80), "moderate" (50-79), "low" (< 50)
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
        - Be specific — never say "the query" or "the topic", say what it actually is
        """

        let userContent = "Original Query: \(query)\n\n\(stageOutputsText)"

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
                maxTokens: 2048
            )

            var responseText = ""
            do {
                for try await text in stream {
                    if Task.isCancelled { break }
                    responseText += text
                }
            } catch {
                if attempt == maxAttempts {
                    return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
                }
                continue // retry
            }

            // Parse the Judge's JSON response
            guard let data = parseJudgeJSON(responseText) else {
                if attempt == maxAttempts {
                    return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
                }
                continue // retry
            }

            do {
                let judgeVerdict = try JSONDecoder().decode(JudgeVerdict.self, from: data)

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
