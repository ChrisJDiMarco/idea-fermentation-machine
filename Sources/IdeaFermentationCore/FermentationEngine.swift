import Foundation

public struct AgentPromptFactory: Sendable {
    public init() {}

    public func prompt(for taskClass: ModelTaskClass) -> String {
        switch taskClass {
        case .extract: "Extract concise idea seeds from raw material. Return JSON matching ExtractedSeed."
        case .tag: "Tag this idea with concise themes, domains, tone, and project relevance. Return JSON matching TagResult."
        case .summarize: "Summarize this source into reusable evidence for idea development. Return JSON matching SourceSummary."
        case .connect: "Find surprising but defensible connections to adjacent ideas and sources. Return JSON array of ConnectionCandidate."
        case .critique: "Identify weak assumptions, objections, missing context, and contradictions. Return JSON matching CritiqueResult."
        case .scoreRipeness: "Score novelty, clarity, evidence, resonance, feasibility, and timing from 0-100. Return JSON matching RipenessResult."
        case .prototypeBrief: "Create a concise build-ready prototype brief with MVP scope, risks, and next actions. Return JSON matching PrototypeBriefDraft."
        }
    }
}

@MainActor
public final class FermentationEngine {
    private let store: IdeaStore
    private let promptFactory: AgentPromptFactory
    private let router: ModelRouter
    private let taste: TasteSignals
    private let calibration: RipenessCalibration

    public init(
        store: IdeaStore,
        promptFactory: AgentPromptFactory = AgentPromptFactory(),
        router: ModelRouter = ModelRouter(),
        taste: TasteSignals = TasteSignals(),
        calibration: RipenessCalibration = RipenessCalibration()
    ) {
        self.store = store
        self.promptFactory = promptFactory
        self.router = router
        self.taste = taste
        self.calibration = calibration
    }

    @discardableResult
    public func queueLoop(maxJobs: Int = 25) throws -> [FermentationJob] {
        let ideas = try store.listIdeas().prefix(maxJobs)
        let run = FermentationRun(status: .pending)
        var jobs: [FermentationJob] = []
        for source in try store.listSources().filter({ $0.extractionStatus == .captured }).prefix(maxJobs) {
            jobs.append(try store.enqueue(FermentationJob(sourceID: source.id, taskClass: .summarize, inputHash: TextHashing.sha256("summarize\n\(source.textHash)"), runID: run.id)))
        }
        for idea in ideas {
            let task: ModelTaskClass = switch idea.status {
            case .inbox: .tag
            case .fermenting: .connect
            case .ripening: .scoreRipeness
            case .ready: .prototypeBrief
            case .archived: .summarize
            }
            let input = "\(idea.title)\n\(idea.body)"
            let inputTokens = CostEstimator.roughTokenCount(input)
            let route = router.route(taskClass: task, inputTokens: inputTokens, outputTokens: 800)
            let status: JobStatus = route.needsApproval ? .needsApproval : .pending
            jobs.append(try store.enqueue(FermentationJob(
                ideaID: idea.id,
                taskClass: task,
                status: status,
                estimatedCostUSD: route.estimatedCostUSD ?? 0,
                modelRoute: route,
                inputHash: TextHashing.sha256("\(task.rawValue)\n\(input)"),
                runID: run.id
            )))
        }
        try store.saveRun(FermentationRun(id: run.id, status: .pending, jobIDs: jobs.map(\.id), totalEstimatedCostUSD: jobs.reduce(0) { $0 + $1.estimatedCostUSD }))
        return jobs
    }

    @discardableResult
    public func runLocalPass(maxIdeas: Int = 25) throws -> [IdeaSeed] {
        let corpus = try store.listIdeas()
        let outcomes = (try? store.buildOutcomes()) ?? []
        let ideas = corpus.prefix(maxIdeas)
        return try ideas.map { idea in
            let updated = localUpdate(idea, corpus: corpus, outcomes: outcomes)
            try store.upsertIdea(updated)
            try persistStructuredLocalResults(for: updated)
            let job = try store.enqueue(FermentationJob(
                ideaID: updated.id,
                taskClass: .scoreRipeness,
                status: .complete,
                estimatedCostUSD: 0,
                modelRoute: ModelRoute(
                    provider: "Local",
                    model: "heuristic-v1",
                    taskClass: .scoreRipeness,
                    rationale: "Local-only heuristic pass; use cloud models for deeper synthesis.",
                    estimatedCostUSD: 0,
                    needsApproval: false
                ),
                inputHash: TextHashing.sha256("local\n\(updated.title)\n\(updated.body)")
            ))
            try store.saveRunLog(AgentRunLog(
                jobID: job.id,
                agentName: "Local Fermentation Agent",
                promptVersion: "local-v1",
                inputTrace: updated.id.uuidString,
                output: "Updated status to \(updated.status.rawValue), stage to \(updated.stage.rawValue), ripeness \(Int(updated.ripeness)).",
                modelUsed: "Local/heuristic-v1"
            ))
            return updated
        }
    }

    /// Runs the local heuristic pass for one idea only — the precise fallback for a
    /// user-initiated agent action when the cloud can't run (no key, capped, or
    /// never-send), so the click still yields an instant local result without
    /// reprocessing the whole corpus.
    @discardableResult
    public func processIdeaLocally(_ idea: IdeaSeed) throws -> IdeaSeed {
        let corpus = try store.listIdeas()
        let updated = localUpdate(idea, corpus: corpus, outcomes: (try? store.buildOutcomes()) ?? [])
        try store.upsertIdea(updated)
        try persistStructuredLocalResults(for: updated)
        return updated
    }

    @discardableResult
    public func runDueLocalJobs(maxJobs: Int = 25, now: Date = Date()) throws -> [FermentationJob] {
        var completed: [FermentationJob] = []
        for job in try store.dueJobs(limit: maxJobs, now: now) {
            guard job.estimatedCostUSD == 0 || job.modelRoute?.provider == "Local" || job.sourceID != nil else { continue }
            try store.markRunning(job.id, runID: job.runID)
            do {
                try completeLocal(job)
                try store.markComplete(job.id)
                completed.append(try store.job(id: job.id))
            } catch {
                try store.markFailed(job.id, error: error.localizedDescription, retryAfter: Date(timeInterval: 300, since: now))
            }
        }
        return completed
    }

    public func tickScheduler(settings: SchedulerSettings, now: Date = Date()) throws -> SchedulerSettings {
        var next = settings
        guard settings.nextLocalRunAt == nil || settings.nextLocalRunAt! <= now else { return next }
        _ = try runLocalPass(maxIdeas: settings.maxLocalJobsPerPass)
        _ = try runDueLocalJobs(maxJobs: settings.maxLocalJobsPerPass, now: now)
        next.nextLocalRunAt = Date(timeInterval: Double(settings.localCadenceMinutes * 60), since: now)
        try store.saveSchedulerSettings(next)
        return next
    }

    @discardableResult
    public func runNext(provider: any LLMProvider, apiKey: String) async throws -> LLMResponse? {
        guard let job = try store.nextRunnableJob() else { return nil }
        return try await runJob(job, provider: provider, apiKey: apiKey)
    }

    /// Runs one specific job to completion. `bypassApproval` is set for
    /// user-initiated actions — the click is the consent, so they run immediately
    /// instead of parking in the approval queue. The scheduler/queue path leaves it
    /// `false`, so unattended jobs still honor the approval gate.
    @discardableResult
    public func runJob(
        _ job: FermentationJob,
        provider: any LLMProvider,
        apiKey: String,
        bypassApproval: Bool = false
    ) async throws -> LLMResponse? {
        let input = try input(for: job)
        let cacheKey = TextHashing.sha256("\(job.taskClass.rawValue)\n\(input)")
        if let cached = try store.cachedOutput(for: cacheKey) {
            try complete(job: job, response: cached, cached: true)
            return cached
        }

        let route = job.modelRoute ?? router.route(
            taskClass: job.taskClass,
            inputTokens: CostEstimator.roughTokenCount(input),
            outputTokens: 800
        )
        if !bypassApproval {
            guard !route.needsApproval else {
                try store.setJobStatus(job.id, status: .needsApproval)
                throw LLMProviderError.approvalRequired(route.estimatedCostUSD)
            }
        }
        guard let model = provider.availableModels.first(where: { $0.name == route.model }) ?? provider.availableModels.first else {
            throw LLMProviderError.invalidResponse(provider.providerName)
        }

        try store.markRunning(job.id, runID: job.runID)
        let request = LLMRequest(
            taskClass: job.taskClass,
            prompt: promptFactory.prompt(for: job.taskClass),
            input: input,
            maxOutputTokens: 1_000
        )
        do {
            let response = try await provider.send(request, model: model, apiKey: apiKey)
            try store.saveCache(key: cacheKey, response: response)
            try complete(job: job, response: response, cached: false)
            return response
        } catch {
            try store.markFailed(job.id, error: error.localizedDescription)
            throw error
        }
    }

    private func input(for job: FermentationJob) throws -> String {
        let base: String
        if let ideaID = job.ideaID {
            let idea = try store.idea(id: ideaID)
            // Tolerate a source that was deleted after it was linked — skip it rather
            // than failing the whole job. deleteSource also scrubs these references.
            let sources = idea.sourceIDs.compactMap { try? store.source(id: $0) }
            base = PrivacyPolicy.preview(idea: idea, sources: sources, taskClass: job.taskClass).payload
        } else if let sourceID = job.sourceID {
            let source = try store.source(id: sourceID)
            // A source flagged never-send must not have ANY of its content leave the
            // machine on a cloud-routed source job — not the body and not the title,
            // since a title alone can be sensitive ("Acme Q3 layoff plan — J. Doe").
            // Send a fully generic placeholder so the run can proceed.
            base = source.neverSendToCloud
                ? "[Private source — content withheld]"
                : "\(source.title)\n\(source.body)"
        } else {
            base = job.inputHash
        }
        return AgentLearning.appendContext(
            to: base,
            ideas: try store.listIdeas(),
            sources: try store.listSources(),
            logs: try store.runLogs(),
            jobs: try store.listJobs(),
            connections: try store.connections(),
            outcomes: try store.buildOutcomes()
        )
    }

    private func complete(job: FermentationJob, response: LLMResponse, cached: Bool) throws {
        try persistStructuredResult(job: job, output: response.text)
        try store.saveRunLog(AgentRunLog(
            jobID: job.id,
            agentName: agentName(for: job.taskClass),
            promptVersion: "v1",
            inputTrace: job.ideaID?.uuidString ?? job.sourceID?.uuidString ?? job.id.uuidString,
            output: response.text,
            modelUsed: cached ? "\(response.provider)/\(response.model) cached" : "\(response.provider)/\(response.model)"
        ))
        // Record what was ACTUALLY spent, not the pre-flight estimate. The estimate
        // systematically undercounts (it prices a bare idea at 800 output tokens, but
        // the real request sends the full payload + learning context and can return up
        // to 1,000), so charging the caps the estimate lets real spend drift over the
        // cap. A cache hit makes no provider call, so it charges nothing.
        let recordedCost: Double
        // Match on provider AND name: a user-configured custom model could share a name
        // with a catalog entry, and matching name-only would price it with the wrong
        // (catalog) rate. An unmatched/unpriced model falls back to the estimate.
        let pricedModel = router.models.first { $0.name == response.model && $0.provider == response.provider }
            ?? PricingCatalog.all.first { $0.name == response.model && $0.provider == response.provider }
        if cached {
            recordedCost = 0
        } else if let pricedModel,
                  let actual = CostEstimator.estimate(model: pricedModel, inputTokens: response.inputTokens, outputTokens: response.outputTokens) {
            recordedCost = actual
        } else {
            recordedCost = job.estimatedCostUSD
        }
        try store.saveUsage(LLMUsageRecord(
            provider: response.provider,
            model: response.model,
            taskClass: job.taskClass,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
            estimatedCostUSD: recordedCost
        ))
        try store.markComplete(job.id)
    }

    private func completeLocal(_ job: FermentationJob) throws {
        if let sourceID = job.sourceID {
            let source = try store.source(id: sourceID)
            let summary = AgentResultInterpreter.sourceSummary(for: source, ideas: try store.listIdeas())
            var next = source
            next.extractionStatus = .connected
            next.linkedIdeaIDs = summary.linkedIdeaIDs
            try store.upsertSource(next)
            try store.saveRunLog(AgentRunLog(jobID: job.id, agentName: "Local Source Agent", promptVersion: "local-v2", inputTrace: sourceID.uuidString, output: summary.summary, modelUsed: "Local/heuristic-v2"))
        } else if let ideaID = job.ideaID {
            let corpus = try store.listIdeas()
            let idea = localUpdate(try store.idea(id: ideaID), corpus: corpus, outcomes: (try? store.buildOutcomes()) ?? [])
            try store.upsertIdea(idea)
            try persistStructuredLocalResults(for: idea)
            try store.saveRunLog(AgentRunLog(jobID: job.id, agentName: "Local Fermentation Agent", promptVersion: "local-v2", inputTrace: ideaID.uuidString, output: "Updated \(idea.title) to ripeness \(Int(idea.ripeness)).", modelUsed: "Local/heuristic-v2"))
        }
    }

    private func persistStructuredResult(job: FermentationJob, output: String) throws {
        if let sourceID = job.sourceID {
            var source = try store.source(id: sourceID)
            let summary = AgentResultInterpreter.sourceSummary(for: source, ideas: try store.listIdeas(), output: output)
            source.body = source.body.isEmpty ? summary.summary : source.body
            source.extractionStatus = .connected
            source.linkedIdeaIDs = summary.linkedIdeaIDs
            try store.upsertSource(source)
            return
        }
        guard let ideaID = job.ideaID else { return }
        var idea = try store.idea(id: ideaID)
        switch job.taskClass {
        case .tag, .extract:
            let result = AgentResultInterpreter.tagResult(for: idea, output: output)
            idea.manualTags = Array(Set(idea.manualTags + result.tags)).sorted()
            if idea.body.isEmpty { idea.body = result.summary }
            try store.upsertIdea(idea)
        case .connect:
            for connection in AgentResultInterpreter.connections(for: idea, candidates: try store.listIdeas(), output: output) {
                try store.saveConnection(IdeaConnection(fromID: connection.fromID, toID: connection.toID, explanation: connection.explanation, confidence: connection.confidence))
            }
        case .critique:
            let result = AgentResultInterpreter.critique(for: idea, output: output)
            try store.saveCritique(IdeaCritique(
                ideaID: idea.id,
                assumptions: result.assumptions,
                risks: result.risks,
                contradictions: result.contradictions,
                source: "\(job.modelRoute?.provider ?? "Cloud")/\(job.modelRoute?.model ?? "model")"
            ))
        case .scoreRipeness:
            let result = AgentResultInterpreter.ripeness(for: idea, output: output)
            try applyRipeness(result, to: &idea)
            try store.upsertIdea(idea)
        case .prototypeBrief:
            let draft = AgentResultInterpreter.brief(for: idea, output: output)
            try store.savePrototypeBrief(PrototypeBrief(ideaID: idea.id, audience: draft.audience, mvpScope: draft.mvpScope, risks: draft.risks, nextActions: draft.nextActions, markdown: draft.markdown))
        case .summarize:
            break
        }
    }

    private func persistStructuredLocalResults(for idea: IdeaSeed) throws {
        let ripeness = AgentResultInterpreter.ripeness(for: idea)
        try store.saveRipenessScore(RipenessScore(ideaID: idea.id, novelty: ripeness.novelty, clarity: ripeness.clarity, evidence: ripeness.evidence, personalResonance: ripeness.personalResonance, feasibility: ripeness.feasibility, timing: ripeness.timing))
        for connection in AgentResultInterpreter.connections(for: idea, candidates: try store.listIdeas()) {
            try store.saveConnection(IdeaConnection(fromID: connection.fromID, toID: connection.toID, explanation: connection.explanation, confidence: connection.confidence))
        }
        // Give every idea a baseline heuristic critique so the Contradictions panes
        // are never empty in pure local mode — but never clobber a richer cloud
        // critique that already exists.
        if try store.critique(for: idea.id) == nil {
            let critique = AgentResultInterpreter.critique(for: idea)
            try store.saveCritique(IdeaCritique(
                ideaID: idea.id,
                assumptions: critique.assumptions,
                risks: critique.risks,
                contradictions: critique.contradictions,
                source: "local"
            ))
        }
        if idea.status == .ready {
            let draft = AgentResultInterpreter.brief(for: idea)
            try store.savePrototypeBrief(PrototypeBrief(ideaID: idea.id, audience: draft.audience, mvpScope: draft.mvpScope, risks: draft.risks, nextActions: draft.nextActions, markdown: draft.markdown))
        }
    }

    private func applyRipeness(_ result: RipenessResult, to idea: inout IdeaSeed) throws {
        idea.novelty = result.novelty
        idea.evidence = result.evidence
        idea.personalResonance = result.personalResonance
        idea.feasibility = result.feasibility
        idea.timing = result.timing
        idea.ripeness = calibration.ripeness(novelty: result.novelty, clarity: result.clarity, evidence: result.evidence, resonance: result.personalResonance, feasibility: result.feasibility, timing: result.timing)
        idea.updatedAt = Date()
        if idea.ripeness >= 78 {
            idea.status = .ready
            idea.stage = .readyToPrototype
        } else if idea.ripeness >= 55 {
            idea.status = .ripening
            idea.stage = .brewing
        }
        try store.saveRipenessScore(RipenessScore(ideaID: idea.id, novelty: result.novelty, clarity: result.clarity, evidence: result.evidence, personalResonance: result.personalResonance, feasibility: result.feasibility, timing: result.timing))
    }

    private func agentName(for taskClass: ModelTaskClass) -> String {
        switch taskClass {
        case .extract: "Capture Triage Agent"
        case .tag: "Tagging Agent"
        case .summarize: "Archivist Agent"
        case .connect: "Connector Agent"
        case .critique: "Critic Agent"
        case .scoreRipeness: "Ripeness Agent"
        case .prototypeBrief: "Prototype Agent"
        }
    }

    /// Generic signal lexicons, stemmed so they line up with `Tokenizer` output.
    /// These are a floor; the operator's own taste profile layers on top.
    private static let noveltyWords = Set(["ai", "agent", "ambient", "private", "local", "memory", "taste", "context", "model", "autonomous"].map(Tokenizer.stem))
    private static let prototypeWords = Set(["prototype", "mvp", "build", "launch", "user", "workflow", "test", "ship", "demo"].map(Tokenizer.stem))

    /// How many resonance points a fully-saturated learned affinity (±1) moves an
    /// idea. Bounded so the learning loop nudges scores without overwhelming the
    /// other five axes — at most ±~3.7 ripeness once averaged across the six.
    private static let learnedResonanceWeight = 22.0

    /// Novelty = how unlike everything you've already captured this idea is, blended
    /// with the lexical signal. The semantic-distance half is the meaningful upgrade:
    /// "novel" stops meaning "uses the word ambient" and starts meaning "I've never
    /// thought anything like this before" — a judgment only possible because the app
    /// holds an embedding of your whole corpus. Falls back to the lexical signal at
    /// cold start, when there is nothing to be distant *from*.
    static func noveltyScore(for idea: IdeaSeed, tokens: Set<String>, interestOverlap: Int, tagBoost: Double, corpus: [IdeaSeed]) -> Double {
        let lexical = min(100, 22
            + Double(tokens.intersection(noveltyWords).count) * 12
            + Double(interestOverlap) * 9
            + tagBoost)

        // A zero-magnitude vector (failed or empty embed) carries no semantic signal —
        // cosine to it is 0, which would otherwise read as "maximally distant" and
        // award full novelty. Treat it as no signal and fall back to the lexical cue.
        func hasSignal(_ vector: [Double]) -> Bool { vector.contains { $0 != 0 } }
        let others = corpus.filter { $0.id != idea.id && hasSignal($0.embedding) }
        guard hasSignal(idea.embedding), !others.isEmpty else { return lexical }

        let nearest = others.map { LocalEmbeddings.cosine(idea.embedding, $0.embedding) }.max() ?? 0
        let distance = min(100, max(0, (1 - nearest) * 100))
        // Distance leads (0.6) so genuine originality drives the score, with the
        // lexical cue (0.4) keeping cold-ish corpora from scoring everything as novel.
        return min(100, 0.6 * distance + 0.4 * lexical)
    }

    private func localUpdate(_ idea: IdeaSeed, corpus: [IdeaSeed], outcomes: [BuildOutcome] = []) -> IdeaSeed {
        var next = idea
        let tokens = Tokenizer.vocabulary("\(idea.title) \(idea.body) \(idea.manualTags.joined(separator: " "))")
        let sourceCount = idea.sourceIDs.count
        let lengthBoost = min(25, Double(idea.body.count) / 40)
        let tagBoost = min(15, Double(idea.manualTags.count * 3))
        let interestOverlap = taste.interestOverlap(tokens)

        // Each axis is scored on its own 0–100 scale so the 6-axis mean below is a
        // fair blend (the old code capped evidence at 30, which silently dragged
        // every ripeness score down).
        let feasibility = min(100, 35 + lengthBoost + tagBoost + min(20, Double(sourceCount) * 5))
        let evidence = min(100, Double(sourceCount) * 22 + (idea.body.isEmpty ? 0 : 8))
        let clarity = AgentResultInterpreter.localClarity(for: idea)
        let novelty = Self.noveltyScore(for: idea, tokens: tokens, interestOverlap: interestOverlap, tagBoost: tagBoost, corpus: corpus)
        let timing = min(100, 30 + Double(tokens.intersection(Self.prototypeWords).count) * 10 + Double(sourceCount) * 6)

        var resonance: Double
        if taste.isActive {
            // Taste-aware: ideas that hit the operator's watch topics resonate.
            resonance = min(100, max(idea.personalResonance, 18 + Double(interestOverlap) * 16 + tagBoost * 0.5))
        } else {
            resonance = max(idea.personalResonance, tagBoost + 35)
        }
        // Phase 6 — fold in the self-tuning model learned from past approvals and
        // archives. Matched on the same curated theme terms the model learns over
        // (tags + title), so the affinity reflects real themes, not body filler.
        // Exactly 0 until something has been taught, so a fresh install scores
        // identically. Applied before the exclusion cap so a written exclusion always
        // overrides a learned preference.
        // Two views of learned taste: the token model (do the words match what you like)
        // and the concept-space manifold (does this idea SIT near what you build, by
        // meaning). The manifold excludes this idea so it never grades its own centroid,
        // and its weight ramps in from a sliver — until it has signal it's a no-op, so
        // behavior is unchanged without it.
        let manifold = TasteManifold.build(ideas: corpus, outcomes: outcomes, excluding: idea.id)
        let tokenAffinity = taste.learnedAffinity(TasteModel.themeTerms(title: idea.title, tags: idea.manualTags))
        let conceptAffinity = manifold.affinity(for: idea.embedding)
        let conceptWeight = manifold.blendWeight
        let affinity = tokenAffinity * (1 - conceptWeight) + conceptAffinity * conceptWeight
        resonance = min(100, max(0, resonance + affinity * Self.learnedResonanceWeight))
        // Explicitly excluded topics should never resonate — and so never ripen.
        if taste.isExcluded(tokens) {
            resonance = min(resonance, 12)
        }

        next.feasibility = feasibility
        next.novelty = novelty
        next.evidence = evidence
        next.timing = timing
        next.personalResonance = resonance
        // Ripeness is a weighted blend of all six axes — equal weights by default
        // (identical to the old mean and the cloud path), re-weighted toward the axes
        // that have actually predicted this operator's build wins once outcomes exist.
        next.ripeness = calibration.ripeness(novelty: novelty, clarity: clarity, evidence: evidence, resonance: resonance, feasibility: feasibility, timing: timing)
        next.updatedAt = Date()

        if next.ripeness >= 78 {
            next.status = .ready
            next.stage = .readyToPrototype
        } else if next.ripeness >= 55 {
            next.status = .ripening
            next.stage = .brewing
        } else if next.status == .inbox {
            next.status = .fermenting
            next.stage = .cooling
        }
        return next
    }
}
