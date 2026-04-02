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

            let summary = await computeVerificationSummary(
                query: query,
                completedStages: completedStages,
                totalStages: totalStages,
                liveResearchUsed: hasWebResearch,
                onEvent: onEvent
            )
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
            hasWebResearch: hasWebResearch
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

    // MARK: - Verification Summary

    func computeVerificationSummary(
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        liveResearchUsed: Bool = false,
        onEvent: @escaping (PipelineEvent) -> Void
    ) async -> VerificationSummary {
        guard completedStages.count >= 2 else {
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        // Pick cheapest available model for analysis
        let candidates: [(provider: LLMProvider, model: String)] = [
            (.gemini, "gemini-2.5-flash"),
            (.xai, "grok-3-fast"),
            (.anthropic, "claude-haiku-4-5"),
        ]

        var analysisModel: LLMModel?
        var analysisKey: String?
        for candidate in candidates {
            if let key = apiKeyManager.apiKey(for: candidate.provider) {
                analysisModel = LLMModel(provider: candidate.provider, model: candidate.model)
                analysisKey = key
                break
            }
        }

        guard let model = analysisModel, let apiKey = analysisKey else {
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        // Build analysis prompt with all stage outputs
        var stageOutputsText = ""
        for stage in completedStages {
            stageOutputsText += "── Stage \(stage.stage) (\(stage.model.provider.shortName) / \(stage.model.model)) ──\n"
            stageOutputsText += stage.content
            stageOutputsText += "\n\n"
        }

        // Build model names list for the prompt so the LLM can reference them by name
        let modelNames = completedStages.map { "\($0.model.provider.shortName) (\($0.model.model))" }.joined(separator: ", ")
        let liveResearchNote = liveResearchUsed ? " Live web research (Tavily) was used to ground Stage 1." : ""

        let systemPrompt = """
        You are an expert verification analyst. You will receive a query and multiple LLM outputs from a multi-stage verification pipeline. \
        The models used were: \(modelNames).\(liveResearchNote)

        Analyze consistency, hallucination risk, and contradictions. Then write 3-4 concise analyst-style bullet points that:
        - Reference the actual query topic (e.g. "Nuclear fusion claims…", not "the query")
        - Name specific models by their short name (Claude, Gemini, Grok) when describing agreement or disagreement
        - Mention live web research grounding if it was used
        - Justify the confidence level based on what the models actually said

        Respond with ONLY valid JSON (no markdown, no code fences):
        {
          "consistencySummary": "Brief description of consistency across models",
          "hallucinationRisk": "Low/Medium/High with brief explanation",
          "confidenceLevel": "High/Moderate/Low",
          "confidenceScore": 0.85,
          "contradictions": [
            {
              "topic": "Specific topic of disagreement",
              "stageA": 1,
              "stageB": 2,
              "description": "Brief description of the contradiction"
            }
          ],
          "analysisBullets": [
            "First expert verdict bullet — topic-specific, referencing models by name",
            "Second bullet — about consensus, corrections, or disagreements found",
            "Third bullet — confidence justification tied to the query content",
            "Optional fourth bullet — live research note or additional insight"
          ]
        }

        Rules:
        - analysisBullets must have 3-4 items, each under 120 characters
        - Each bullet must feel unique to THIS specific query, never generic
        - If there are no contradictions, return an empty array
        - confidenceScore: 0.0 to 1.0
        """

        let userContent = "Original Query: \(query)\n\n\(stageOutputsText)"

        let service = LLMServiceFactory.service(for: model.provider)
        let stream = service.streamCompletion(
            model: model.model,
            systemPrompt: systemPrompt,
            userContent: userContent,
            apiKey: apiKey,
            maxTokens: 1024
        )

        // Collect the full response (no streaming to UI)
        var responseText = ""
        do {
            for try await text in stream {
                if Task.isCancelled { break }
                responseText += text
            }
        } catch {
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        // Parse JSON response
        guard let data = responseText.data(using: .utf8) else {
            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }

        do {
            let analysis = try JSONDecoder().decode(AnalysisResponse.self, from: data)

            let contradictions = analysis.contradictions.map { c in
                Contradiction(
                    topic: c.topic,
                    stageA: c.stageA,
                    stageB: c.stageB,
                    description: c.description
                )
            }

            let confidenceText: String
            if let score = analysis.confidenceScore {
                let pct = Int(score * 100)
                confidenceText = "\(analysis.confidenceLevel) (\(pct)%)"
            } else {
                confidenceText = analysis.confidenceLevel
            }

            return VerificationSummary(
                consistency: analysis.consistencySummary,
                hallucinations: analysis.hallucinationRisk,
                confidence: confidenceText,
                contradictions: contradictions,
                confidenceScore: analysis.confidenceScore,
                isAnalyzed: true,
                analysisBullets: analysis.analysisBullets ?? []
            )
        } catch {
            // JSON parsing failed — try to strip markdown fences and retry
            let cleaned = responseText
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let cleanedData = cleaned.data(using: .utf8),
               let analysis = try? JSONDecoder().decode(AnalysisResponse.self, from: cleanedData) {
                let contradictions = analysis.contradictions.map { c in
                    Contradiction(
                        topic: c.topic,
                        stageA: c.stageA,
                        stageB: c.stageB,
                        description: c.description
                    )
                }

                let confidenceText: String
                if let score = analysis.confidenceScore {
                    let pct = Int(score * 100)
                    confidenceText = "\(analysis.confidenceLevel) (\(pct)%)"
                } else {
                    confidenceText = analysis.confidenceLevel
                }

                return VerificationSummary(
                    consistency: analysis.consistencySummary,
                    hallucinations: analysis.hallucinationRisk,
                    confidence: confidenceText,
                    contradictions: contradictions,
                    confidenceScore: analysis.confidenceScore,
                    isAnalyzed: true,
                    analysisBullets: analysis.analysisBullets ?? []
                )
            }

            return fallbackSummary(query: query, completedStages: completedStages, totalStages: totalStages, liveResearchUsed: liveResearchUsed)
        }
    }

    /// Generates a contextual fallback summary using pipeline metadata when LLM analysis is unavailable.
    /// Builds dynamic bullet points from the query topic, model names, and live research status.
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

        // Generate contextual fallback bullets from available pipeline metadata
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

    /// Builds contextual bullet points from pipeline metadata when no LLM analysis is available.
    /// Extracts a topic snippet from the query and references actual model names used.
    private static func buildFallbackBullets(
        query: String,
        completedStages: [(stage: Int, model: LLMModel, content: String)],
        totalStages: Int,
        liveResearchUsed: Bool
    ) -> [String] {
        var bullets: [String] = []

        // Extract a short topic from the query (first ~60 chars, breaking at word boundary)
        let topicSnippet: String = {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count <= 60 { return trimmed }
            let prefix = String(trimmed.prefix(60))
            if let lastSpace = prefix.lastIndex(of: " ") {
                return String(prefix[prefix.startIndex..<lastSpace]) + "…"
            }
            return prefix + "…"
        }()

        // Bullet 1: Model names used for this query
        let modelShortNames = completedStages.map { $0.model.provider.shortName }
        let uniqueNames = NSOrderedSet(array: modelShortNames).array as! [String]
        bullets.append("Queried \"\(topicSnippet)\" through \(uniqueNames.joined(separator: ", "))")

        // Bullet 2: Pipeline completion status
        let completed = completedStages.count
        if completed == totalStages {
            bullets.append("All \(completed) verification stages completed successfully")
        } else {
            bullets.append("\(completed) of \(totalStages) stages completed — partial coverage")
        }

        // Bullet 3: Live research note or general grounding note
        if liveResearchUsed {
            bullets.append("Grounded with live web data via Tavily search")
        } else {
            bullets.append("Based on model training data — no live web sources used")
        }

        return bullets
    }
}
