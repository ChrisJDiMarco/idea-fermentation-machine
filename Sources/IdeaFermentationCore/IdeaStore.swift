import Foundation

public final class IdeaStore {
    public let databaseURL: URL
    private let db: SQLiteDatabase

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        db = try SQLiteDatabase(path: databaseURL.path)
        try migrate()
    }

    public static func applicationSupportURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("IdeaFermentationMachine", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    public static func live() throws -> IdeaStore {
        let folder = try applicationSupportURL()
        return try IdeaStore(databaseURL: folder.appendingPathComponent("ideas.sqlite"))
    }

    public func migrate() throws {
        try db.execute("""
        CREATE TABLE IF NOT EXISTS idea_seeds (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            status TEXT NOT NULL,
            stage TEXT NOT NULL,
            source_ids TEXT NOT NULL,
            manual_tags TEXT NOT NULL,
            text_hash TEXT NOT NULL UNIQUE,
            embedding TEXT NOT NULL,
            ripeness REAL NOT NULL,
            novelty REAL NOT NULL,
            feasibility REAL NOT NULL,
            evidence REAL NOT NULL,
            personal_resonance REAL NOT NULL,
            timing REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS idea_search
        USING fts5(id UNINDEXED, title, body, tags)
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS source_items (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at REAL NOT NULL,
            file_path TEXT,
            url TEXT,
            extraction_status TEXT NOT NULL,
            linked_idea_ids TEXT NOT NULL,
            never_send_to_cloud INTEGER NOT NULL,
            text_hash TEXT NOT NULL UNIQUE,
            metadata TEXT NOT NULL
        )
        """)
        try db.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS source_search
        USING fts5(id UNINDEXED, title, body)
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS idea_connections (
            id TEXT PRIMARY KEY,
            from_id TEXT NOT NULL,
            to_id TEXT NOT NULL,
            explanation TEXT NOT NULL,
            confidence REAL NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS fermentation_jobs (
            id TEXT PRIMARY KEY,
            idea_id TEXT,
            source_id TEXT,
            task_class TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER NOT NULL,
            estimated_cost_usd REAL NOT NULL,
            model_route TEXT,
            input_hash TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            scheduled_at REAL,
            completed_at REAL,
            last_error TEXT,
            retry_after REAL,
            run_id TEXT
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS fermentation_runs (
            id TEXT PRIMARY KEY,
            started_at REAL NOT NULL,
            completed_at REAL,
            status TEXT NOT NULL,
            job_ids TEXT NOT NULL,
            total_estimated_cost_usd REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS agent_run_logs (
            id TEXT PRIMARY KEY,
            job_id TEXT NOT NULL,
            agent_name TEXT NOT NULL,
            prompt_version TEXT NOT NULL,
            input_trace TEXT NOT NULL,
            output TEXT NOT NULL,
            model_used TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS ripeness_scores (
            id TEXT PRIMARY KEY,
            idea_id TEXT NOT NULL,
            novelty REAL NOT NULL,
            clarity REAL NOT NULL,
            evidence REAL NOT NULL,
            personal_resonance REAL NOT NULL,
            feasibility REAL NOT NULL,
            timing REAL NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS prototype_briefs (
            id TEXT PRIMARY KEY,
            idea_id TEXT NOT NULL,
            audience TEXT NOT NULL,
            mvp_scope TEXT NOT NULL,
            risks TEXT NOT NULL,
            next_actions TEXT NOT NULL,
            markdown TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS idea_critiques (
            id TEXT PRIMARY KEY,
            idea_id TEXT NOT NULL,
            assumptions TEXT NOT NULL,
            risks TEXT NOT NULL,
            contradictions TEXT NOT NULL,
            source TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS build_outcomes (
            id TEXT PRIMARY KEY,
            idea_id TEXT NOT NULL,
            result TEXT NOT NULL,
            note TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS llm_usage_records (
            id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            task_class TEXT NOT NULL,
            input_tokens INTEGER NOT NULL,
            output_tokens INTEGER NOT NULL,
            estimated_cost_usd REAL NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS llm_cache (
            cache_key TEXT PRIMARY KEY,
            output TEXT NOT NULL,
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try db.execute("""
        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """)
        try migrateV2Columns()
        try createIndices()
        // The embedding vector space has changed twice. v3 fixed the non-deterministic
        // `String.hashValue` hashing; v4 moves to on-device NLEmbedding semantic
        // vectors (a different dimensionality), so any vector written by an earlier
        // build must be recomputed. The re-embed and the version bump commit together,
        // so an interrupted upgrade re-runs cleanly next launch rather than leaving a
        // database whose vectors live in two incompatible spaces.
        if try currentSchemaVersion() < 4 {
            try db.transaction {
                try reembedAllIdeas()
                try db.execute("PRAGMA user_version = 4")
            }
        }
    }

    /// Secondary indices for the hot lookups (job scheduling, per-idea children,
    /// usage aggregation). All `IF NOT EXISTS`, so this is safe to run every launch.
    private func createIndices() throws {
        let statements = [
            "CREATE INDEX IF NOT EXISTS idx_jobs_status ON fermentation_jobs(status)",
            "CREATE INDEX IF NOT EXISTS idx_jobs_scheduled ON fermentation_jobs(status, scheduled_at)",
            "CREATE INDEX IF NOT EXISTS idx_ideas_status ON idea_seeds(status)",
            "CREATE INDEX IF NOT EXISTS idx_sources_type ON source_items(type)",
            "CREATE INDEX IF NOT EXISTS idx_connections_from ON idea_connections(from_id)",
            "CREATE INDEX IF NOT EXISTS idx_connections_to ON idea_connections(to_id)",
            "CREATE INDEX IF NOT EXISTS idx_ripeness_idea ON ripeness_scores(idea_id)",
            "CREATE INDEX IF NOT EXISTS idx_critiques_idea ON idea_critiques(idea_id)",
            "CREATE INDEX IF NOT EXISTS idx_briefs_idea ON prototype_briefs(idea_id)",
            "CREATE INDEX IF NOT EXISTS idx_outcomes_idea ON build_outcomes(idea_id)",
            "CREATE INDEX IF NOT EXISTS idx_logs_job ON agent_run_logs(job_id)",
            "CREATE INDEX IF NOT EXISTS idx_usage_created ON llm_usage_records(created_at)"
        ]
        for statement in statements {
            try db.execute(statement)
        }
    }

    private func currentSchemaVersion() throws -> Int {
        Int(try db.query("PRAGMA user_version").first?.int("user_version") ?? 0)
    }

    private func reembedAllIdeas() throws {
        for idea in try listIdeas() {
            var updated = idea
            updated.embedding = LocalEmbeddings.embed(embeddingText(for: idea))
            try upsertIdea(updated)
        }
    }

    /// The canonical text an idea's embedding is derived from. Mirrors the
    /// `combined` string built in `createIdea` so re-embedding stays consistent.
    private func embeddingText(for idea: IdeaSeed) -> String {
        "\(idea.title)\n\(idea.body)\n\(idea.manualTags.joined(separator: " "))"
    }

    private func migrateV2Columns() throws {
        try addColumnIfMissing(table: "source_items", column: "metadata", definition: "TEXT NOT NULL DEFAULT '{}'")
        try addColumnIfMissing(table: "fermentation_jobs", column: "scheduled_at", definition: "REAL")
        try addColumnIfMissing(table: "fermentation_jobs", column: "completed_at", definition: "REAL")
        try addColumnIfMissing(table: "fermentation_jobs", column: "last_error", definition: "TEXT")
        try addColumnIfMissing(table: "fermentation_jobs", column: "retry_after", definition: "REAL")
        try addColumnIfMissing(table: "fermentation_jobs", column: "run_id", definition: "TEXT")
    }

    private func addColumnIfMissing(table: String, column: String, definition: String) throws {
        let columns = try db.query("PRAGMA table_info(\(table))").compactMap { $0["name"] ?? nil }
        guard !columns.contains(column) else { return }
        try db.execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
    }

    @discardableResult
    public func createIdea(title: String, body: String, tags: [String] = [], status: IdeaStatus = .inbox, stage: FermentationStage = .seed) throws -> IdeaSeed {
        let combined = "\(title)\n\(body)\n\(tags.joined(separator: " "))"
        let hash = TextHashing.sha256(combined)
        guard try db.query("SELECT id FROM idea_seeds WHERE text_hash = ?", [.text(hash)]).isEmpty else {
            throw IdeaStoreError.duplicate
        }
        let idea = IdeaSeed(
            title: title,
            body: body,
            status: status,
            stage: stage,
            manualTags: tags,
            textHash: hash,
            embedding: LocalEmbeddings.embed(combined)
        )
        try upsertIdea(idea)
        return idea
    }

    public func upsertIdea(_ idea: IdeaSeed) throws {
        // Base row + FTS mirror must commit together; a crash between them used to
        // leave the search index pointing at stale or missing text.
        try db.transaction {
            try db.execute("""
            INSERT INTO idea_seeds VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                body = excluded.body,
                updated_at = excluded.updated_at,
                status = excluded.status,
                stage = excluded.stage,
                source_ids = excluded.source_ids,
                manual_tags = excluded.manual_tags,
                text_hash = excluded.text_hash,
                embedding = excluded.embedding,
                ripeness = excluded.ripeness,
                novelty = excluded.novelty,
                feasibility = excluded.feasibility,
                evidence = excluded.evidence,
                personal_resonance = excluded.personal_resonance,
                timing = excluded.timing
            """, try ideaBindings(idea))
            try db.execute("DELETE FROM idea_search WHERE id = ?", [.text(idea.id.uuidString)])
            try db.execute("INSERT INTO idea_search(id, title, body, tags) VALUES (?, ?, ?, ?)", [
                .text(idea.id.uuidString),
                .text(idea.title),
                .text(idea.body),
                .text(idea.manualTags.joined(separator: " "))
            ])
        }
    }

    public func updateIdeaStatus(_ id: UUID, status: IdeaStatus, stage: FermentationStage? = nil) throws {
        var idea = try idea(id: id)
        idea.status = status
        if let stage { idea.stage = stage }
        idea.updatedAt = Date()
        try upsertIdea(idea)
    }

    public func idea(id: UUID) throws -> IdeaSeed {
        guard let row = try db.query("SELECT * FROM idea_seeds WHERE id = ?", [.text(id.uuidString)]).first else {
            throw IdeaStoreError.notFound
        }
        return try decodeIdea(row)
    }

    public func idea(textHash: String) throws -> IdeaSeed? {
        try db.query("SELECT * FROM idea_seeds WHERE text_hash = ?", [.text(textHash)]).first.map(decodeIdea)
    }

    public func listIdeas(status: IdeaStatus? = nil) throws -> [IdeaSeed] {
        let rows: [[String: String?]]
        if let status {
            rows = try db.query("SELECT * FROM idea_seeds WHERE status = ? ORDER BY updated_at DESC", [.text(status.rawValue)])
        } else {
            rows = try db.query("SELECT * FROM idea_seeds ORDER BY updated_at DESC")
        }
        return try rows.map(decodeIdea)
    }

    public func searchIdeas(_ query: String) throws -> [IdeaSeed] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try listIdeas() }
        guard let match = Self.ftsMatchQuery(trimmed) else { return try listIdeas() }
        let rows = try db.query("""
        SELECT idea_seeds.* FROM idea_search
        JOIN idea_seeds ON idea_seeds.id = idea_search.id
        WHERE idea_search MATCH ?
        ORDER BY rank
        """, [.text(match)])
        let results = try rows.map(decodeIdea)
        // Keyword search is precise but brittle. If it finds nothing, fall back to
        // the semantic index so a near-miss phrasing still surfaces related ideas.
        if results.isEmpty {
            return try semanticIdeas(trimmed)
        }
        return results
    }

    /// Turns arbitrary user input into a safe FTS5 MATCH expression by extracting
    /// alphanumeric tokens and quoting each as a literal term. Without this, a
    /// query like `c++` or `title:` throws an FTS syntax error that the UI then
    /// shows as a scary alert. Returns nil when nothing searchable remains.
    static func ftsMatchQuery(_ raw: String) -> String? {
        let tokens = raw.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0)\"" }.joined(separator: " ")
    }

    public func deleteIdea(_ id: UUID) throws {
        // Delete the idea and every row that belongs to it, atomically. Without the
        // cascade, connections, ripeness history, critiques, and briefs were
        // orphaned and lingered in the Patterns view forever.
        let key = id.uuidString
        try db.transaction {
            try db.execute("DELETE FROM idea_search WHERE id = ?", [.text(key)])
            try db.execute("DELETE FROM idea_seeds WHERE id = ?", [.text(key)])
            try db.execute("DELETE FROM idea_connections WHERE from_id = ? OR to_id = ?", [.text(key), .text(key)])
            try db.execute("DELETE FROM ripeness_scores WHERE idea_id = ?", [.text(key)])
            try db.execute("DELETE FROM idea_critiques WHERE idea_id = ?", [.text(key)])
            try db.execute("DELETE FROM prototype_briefs WHERE idea_id = ?", [.text(key)])
            try db.execute("DELETE FROM build_outcomes WHERE idea_id = ?", [.text(key)])
        }
    }

    public func semanticIdeas(_ query: String, limit: Int = 8) throws -> [IdeaSeed] {
        let queryVector = LocalEmbeddings.embed(query)
        return try listIdeas()
            .map { (idea: $0, score: LocalEmbeddings.cosine($0.embedding, queryVector)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.idea)
    }

    @discardableResult
    public func createSource(_ source: SourceItem) throws -> SourceItem {
        let hash = source.textHash.isEmpty ? TextHashing.sha256("\(source.title)\n\(source.body)") : source.textHash
        guard try db.query("SELECT id FROM source_items WHERE text_hash = ?", [.text(hash)]).isEmpty else {
            throw IdeaStoreError.duplicate
        }
        var stored = source
        stored.textHash = hash
        try upsertSource(stored)
        return stored
    }

    public func source(textHash: String) throws -> SourceItem? {
        try db.query("SELECT * FROM source_items WHERE text_hash = ?", [.text(textHash)]).first.map(decodeSource)
    }

    public func upsertSource(_ source: SourceItem) throws {
        try db.transaction {
            try db.execute("""
            INSERT INTO source_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                type = excluded.type,
                title = excluded.title,
                body = excluded.body,
                file_path = excluded.file_path,
                url = excluded.url,
                extraction_status = excluded.extraction_status,
                linked_idea_ids = excluded.linked_idea_ids,
                never_send_to_cloud = excluded.never_send_to_cloud,
                text_hash = excluded.text_hash,
                metadata = excluded.metadata
            """, try sourceBindings(source))
            try db.execute("DELETE FROM source_search WHERE id = ?", [.text(source.id.uuidString)])
            try db.execute("INSERT INTO source_search(id, title, body) VALUES (?, ?, ?)", [
                .text(source.id.uuidString),
                .text(source.title),
                .text(source.body)
            ])
        }
    }

    public func listSources(type: SourceType? = nil) throws -> [SourceItem] {
        let rows: [[String: String?]]
        if let type {
            rows = try db.query("SELECT * FROM source_items WHERE type = ? ORDER BY created_at DESC", [.text(type.rawValue)])
        } else {
            rows = try db.query("SELECT * FROM source_items ORDER BY created_at DESC")
        }
        return try rows.map(decodeSource)
    }

    public func source(id: UUID) throws -> SourceItem {
        guard let row = try db.query("SELECT * FROM source_items WHERE id = ?", [.text(id.uuidString)]).first else {
            throw IdeaStoreError.notFound
        }
        return try decodeSource(row)
    }

    public func deleteSource(_ id: UUID) throws {
        let key = id.uuidString
        // Ideas keep a list of linked source IDs. Drop the deleted one so a later
        // cloud job doesn't fail trying to load a source that no longer exists.
        let affectedIdeas = try listIdeas().filter { $0.sourceIDs.contains(id) }
        try db.transaction {
            try db.execute("DELETE FROM source_search WHERE id = ?", [.text(key)])
            try db.execute("DELETE FROM source_items WHERE id = ?", [.text(key)])
            for idea in affectedIdeas {
                var updated = idea
                updated.sourceIDs.removeAll { $0 == id }
                try upsertIdea(updated)
            }
        }
    }

    public func searchSources(_ query: String) throws -> [SourceItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try listSources() }
        guard let match = Self.ftsMatchQuery(trimmed) else { return try listSources() }
        let rows = try db.query("""
        SELECT source_items.* FROM source_search
        JOIN source_items ON source_items.id = source_search.id
        WHERE source_search MATCH ?
        ORDER BY rank
        """, [.text(match)])
        return try rows.map(decodeSource)
    }

    @discardableResult
    public func enqueue(_ job: FermentationJob) throws -> FermentationJob {
        try db.execute("""
        INSERT INTO fermentation_jobs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            status = excluded.status,
            retry_count = excluded.retry_count,
            estimated_cost_usd = excluded.estimated_cost_usd,
            model_route = excluded.model_route,
            input_hash = excluded.input_hash,
            updated_at = excluded.updated_at,
            scheduled_at = excluded.scheduled_at,
            completed_at = excluded.completed_at,
            last_error = excluded.last_error,
            retry_after = excluded.retry_after,
            run_id = excluded.run_id
        """, try jobBindings(job))
        return job
    }

    public func listJobs(status: JobStatus? = nil) throws -> [FermentationJob] {
        let rows: [[String: String?]]
        if let status {
            rows = try db.query("SELECT * FROM fermentation_jobs WHERE status = ? ORDER BY created_at ASC", [.text(status.rawValue)])
        } else {
            rows = try db.query("SELECT * FROM fermentation_jobs ORDER BY created_at ASC")
        }
        return try rows.map(decodeJob)
    }

    public func nextRunnableJob() throws -> FermentationJob? {
        try dueJobs(limit: 1, includeCloudApproval: false).first
    }

    public func dueJobs(limit: Int = 25, includeCloudApproval: Bool = false, now: Date = Date()) throws -> [FermentationJob] {
        let statuses = includeCloudApproval ? [JobStatus.pending.rawValue, JobStatus.needsApproval.rawValue] : [JobStatus.pending.rawValue]
        let placeholders = statuses.map { _ in "?" }.joined(separator: ",")
        var bindings = statuses.map(SQLiteValue.text)
        bindings.append(.double(now.timeIntervalSince1970))
        bindings.append(.double(now.timeIntervalSince1970))
        bindings.append(.int(Int64(limit)))
        let rows = try db.query("""
        SELECT * FROM fermentation_jobs
        WHERE status IN (\(placeholders))
          AND (scheduled_at IS NULL OR scheduled_at <= ?)
          AND (retry_after IS NULL OR retry_after <= ?)
        ORDER BY COALESCE(scheduled_at, created_at) ASC
        LIMIT ?
        """, bindings)
        return try rows.map(decodeJob)
    }

    public func setJobStatus(_ id: UUID, status: JobStatus, retryCount: Int? = nil) throws {
        var job = try job(id: id)
        job.status = status
        if let retryCount { job.retryCount = retryCount }
        job.updatedAt = Date()
        try enqueue(job)
    }

    public func approveJob(_ id: UUID) throws {
        try setJobStatus(id, status: .pending)
    }

    public func markRunning(_ id: UUID, runID: UUID? = nil) throws {
        var job = try job(id: id)
        job.status = .running
        job.runID = runID
        job.lastError = nil
        job.updatedAt = Date()
        try enqueue(job)
    }

    public func markComplete(_ id: UUID) throws {
        var job = try job(id: id)
        job.status = .complete
        job.completedAt = Date()
        job.retryAfter = nil
        job.lastError = nil
        job.updatedAt = Date()
        try enqueue(job)
    }

    public func markFailed(_ id: UUID, error: String, retryAfter: Date? = nil) throws {
        var job = try job(id: id)
        job.status = .failed
        job.retryCount += 1
        job.lastError = error
        job.retryAfter = retryAfter
        job.updatedAt = Date()
        try enqueue(job)
    }

    public func resumeInterruptedJobs() throws {
        for job in try listJobs(status: .running) {
            try setJobStatus(job.id, status: .pending, retryCount: job.retryCount)
        }
    }

    public func job(id: UUID) throws -> FermentationJob {
        guard let row = try db.query("SELECT * FROM fermentation_jobs WHERE id = ?", [.text(id.uuidString)]).first else {
            throw IdeaStoreError.notFound
        }
        return try decodeJob(row)
    }

    public func saveRunLog(_ log: AgentRunLog) throws {
        try db.execute("""
        INSERT INTO agent_run_logs VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            .text(log.id.uuidString),
            .text(log.jobID.uuidString),
            .text(log.agentName),
            .text(log.promptVersion),
            .text(log.inputTrace),
            .text(log.output),
            .text(log.modelUsed),
            .double(log.createdAt.timeIntervalSince1970)
        ])
    }

    public func saveConnection(_ connection: IdeaConnection) throws {
        // Connections are semantically undirected: A↔B is the same edge as B↔A.
        // Each local pass re-derives the same pairs, so without de-duplication the
        // table grows without bound and the Patterns view fills with repeats. Keep
        // exactly one row per unordered pair, refreshing it in place.
        let from = connection.fromID.uuidString
        let to = connection.toID.uuidString
        let existing = try db.query("""
        SELECT id FROM idea_connections
        WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)
        LIMIT 1
        """, [.text(from), .text(to), .text(to), .text(from)]).first

        if let id = (existing?["id"] ?? nil) {
            try db.execute("""
            UPDATE idea_connections
            SET explanation = ?, confidence = ?, created_at = ?
            WHERE id = ?
            """, [
                .text(connection.explanation),
                .double(connection.confidence),
                .double(connection.createdAt.timeIntervalSince1970),
                .text(id)
            ])
            return
        }

        try db.execute("""
        INSERT OR REPLACE INTO idea_connections VALUES (?, ?, ?, ?, ?, ?)
        """, [
            .text(connection.id.uuidString),
            .text(from),
            .text(to),
            .text(connection.explanation),
            .double(connection.confidence),
            .double(connection.createdAt.timeIntervalSince1970)
        ])
    }

    public func connections(for ideaID: UUID? = nil) throws -> [IdeaConnection] {
        let rows: [[String: String?]]
        if let ideaID {
            rows = try db.query("""
            SELECT * FROM idea_connections
            WHERE from_id = ? OR to_id = ?
            ORDER BY confidence DESC, created_at DESC
            """, [.text(ideaID.uuidString), .text(ideaID.uuidString)])
        } else {
            rows = try db.query("SELECT * FROM idea_connections ORDER BY confidence DESC, created_at DESC")
        }
        return rows.map { row in
            IdeaConnection(
                id: UUID(uuidString: row.required("id"))!,
                fromID: UUID(uuidString: row.required("from_id"))!,
                toID: UUID(uuidString: row.required("to_id"))!,
                explanation: row.required("explanation"),
                confidence: row.double("confidence"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    public func saveRipenessScore(_ score: RipenessScore) throws {
        try db.execute("""
        INSERT INTO ripeness_scores VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            .text(score.id.uuidString),
            .text(score.ideaID.uuidString),
            .double(score.novelty),
            .double(score.clarity),
            .double(score.evidence),
            .double(score.personalResonance),
            .double(score.feasibility),
            .double(score.timing),
            .double(score.createdAt.timeIntervalSince1970)
        ])
    }

    public func ripenessScores(for ideaID: UUID? = nil) throws -> [RipenessScore] {
        let rows = try ideaID.map {
            try db.query("SELECT * FROM ripeness_scores WHERE idea_id = ? ORDER BY created_at DESC", [.text($0.uuidString)])
        } ?? db.query("SELECT * FROM ripeness_scores ORDER BY created_at DESC")
        return rows.map { row in
            RipenessScore(
                id: UUID(uuidString: row.required("id"))!,
                ideaID: UUID(uuidString: row.required("idea_id"))!,
                novelty: row.double("novelty"),
                clarity: row.double("clarity"),
                evidence: row.double("evidence"),
                personalResonance: row.double("personal_resonance"),
                feasibility: row.double("feasibility"),
                timing: row.double("timing"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    /// Persists the latest critique for an idea, keeping exactly one row per idea.
    public func saveCritique(_ critique: IdeaCritique) throws {
        try db.transaction {
        try db.execute("DELETE FROM idea_critiques WHERE idea_id = ?", [.text(critique.ideaID.uuidString)])
        try db.execute("""
        INSERT INTO idea_critiques VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [
            .text(critique.id.uuidString),
            .text(critique.ideaID.uuidString),
            .text(try JSONSupport.encode(critique.assumptions)),
            .text(try JSONSupport.encode(critique.risks)),
            .text(try JSONSupport.encode(critique.contradictions)),
            .text(critique.source),
            .double(critique.createdAt.timeIntervalSince1970)
        ])
        }
    }

    public func critique(for ideaID: UUID) throws -> IdeaCritique? {
        try critiques().first { $0.ideaID == ideaID }
    }

    public func critiques() throws -> [IdeaCritique] {
        try db.query("SELECT * FROM idea_critiques ORDER BY created_at DESC").map { row in
            IdeaCritique(
                id: UUID(uuidString: row.required("id"))!,
                ideaID: UUID(uuidString: row.required("idea_id"))!,
                assumptions: try JSONSupport.decode([String].self, from: row["assumptions"] ?? nil),
                risks: try JSONSupport.decode([String].self, from: row["risks"] ?? nil),
                contradictions: try JSONSupport.decode([String].self, from: row["contradictions"] ?? nil),
                source: row.required("source"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    public func savePrototypeBrief(_ brief: PrototypeBrief) throws {
        try db.execute("""
        INSERT OR REPLACE INTO prototype_briefs VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            .text(brief.id.uuidString),
            .text(brief.ideaID.uuidString),
            .text(brief.audience),
            .text(brief.mvpScope),
            .text(brief.risks),
            .text(try JSONSupport.encode(brief.nextActions)),
            .text(brief.markdown),
            .double(brief.createdAt.timeIntervalSince1970)
        ])
    }

    public func prototypeBriefs(for ideaID: UUID? = nil) throws -> [PrototypeBrief] {
        let rows = try ideaID.map {
            try db.query("SELECT * FROM prototype_briefs WHERE idea_id = ? ORDER BY created_at DESC", [.text($0.uuidString)])
        } ?? db.query("SELECT * FROM prototype_briefs ORDER BY created_at DESC")
        return try rows.map { row in
            PrototypeBrief(
                id: UUID(uuidString: row.required("id"))!,
                ideaID: UUID(uuidString: row.required("idea_id"))!,
                audience: row.required("audience"),
                mvpScope: row.required("mvp_scope"),
                risks: row.required("risks"),
                nextActions: try JSONSupport.decode([String].self, from: row["next_actions"] ?? nil),
                markdown: row.required("markdown"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    /// Records what happened when the operator took an idea to build. Keeps one
    /// outcome per idea (the latest), like critiques.
    public func saveBuildOutcome(_ outcome: BuildOutcome) throws {
        try db.transaction {
            try db.execute("DELETE FROM build_outcomes WHERE idea_id = ?", [.text(outcome.ideaID.uuidString)])
            try db.execute("INSERT INTO build_outcomes VALUES (?, ?, ?, ?, ?)", [
                .text(outcome.id.uuidString),
                .text(outcome.ideaID.uuidString),
                .text(outcome.result.rawValue),
                .text(outcome.note),
                .double(outcome.createdAt.timeIntervalSince1970)
            ])
        }
    }

    public func buildOutcome(for ideaID: UUID) throws -> BuildOutcome? {
        try buildOutcomes().first { $0.ideaID == ideaID }
    }

    public func buildOutcomes() throws -> [BuildOutcome] {
        try db.query("SELECT * FROM build_outcomes ORDER BY created_at DESC").map { row in
            BuildOutcome(
                id: UUID(uuidString: row.required("id"))!,
                ideaID: UUID(uuidString: row.required("idea_id"))!,
                result: BuildResult(rawValue: row.required("result")) ?? .built,
                note: row.required("note"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    public func saveRun(_ run: FermentationRun) throws {
        try db.execute("""
        INSERT OR REPLACE INTO fermentation_runs VALUES (?, ?, ?, ?, ?, ?)
        """, [
            .text(run.id.uuidString),
            .double(run.startedAt.timeIntervalSince1970),
            run.completedAt.map { .double($0.timeIntervalSince1970) } ?? .null,
            .text(run.status.rawValue),
            .text(try JSONSupport.encode(run.jobIDs.map(\.uuidString))),
            .double(run.totalEstimatedCostUSD)
        ])
    }

    public func runs() throws -> [FermentationRun] {
        try db.query("SELECT * FROM fermentation_runs ORDER BY started_at DESC").map { row in
            let jobIDs: [String] = try JSONSupport.decode([String].self, from: row["job_ids"] ?? nil)
            return FermentationRun(
                id: UUID(uuidString: row.required("id"))!,
                startedAt: Date(timeIntervalSince1970: row.double("started_at")),
                completedAt: (row["completed_at"] ?? nil).map { Date(timeIntervalSince1970: Double($0) ?? 0) },
                status: JobStatus(rawValue: row.required("status")) ?? .failed,
                jobIDs: jobIDs.compactMap(UUID.init(uuidString:)),
                totalEstimatedCostUSD: row.double("total_estimated_cost_usd")
            )
        }
    }

    public func runLogs(jobID: UUID? = nil) throws -> [AgentRunLog] {
        let rows: [[String: String?]]
        if let jobID {
            rows = try db.query("SELECT * FROM agent_run_logs WHERE job_id = ? ORDER BY created_at DESC", [.text(jobID.uuidString)])
        } else {
            rows = try db.query("SELECT * FROM agent_run_logs ORDER BY created_at DESC")
        }
        return rows.map { row in
            AgentRunLog(
                id: UUID(uuidString: row.required("id"))!,
                jobID: UUID(uuidString: row.required("job_id"))!,
                agentName: row.required("agent_name"),
                promptVersion: row.required("prompt_version"),
                inputTrace: row.required("input_trace"),
                output: row.required("output"),
                modelUsed: row.required("model_used"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    public func saveUsage(_ usage: LLMUsageRecord) throws {
        try db.execute("""
        INSERT INTO llm_usage_records VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            .text(usage.id.uuidString),
            .text(usage.provider),
            .text(usage.model),
            .text(usage.taskClass.rawValue),
            .int(Int64(usage.inputTokens)),
            .int(Int64(usage.outputTokens)),
            .double(usage.estimatedCostUSD),
            .double(usage.createdAt.timeIntervalSince1970)
        ])
    }

    public func usageRecords() throws -> [LLMUsageRecord] {
        try db.query("SELECT * FROM llm_usage_records ORDER BY created_at DESC").map { row in
            LLMUsageRecord(
                id: UUID(uuidString: row.required("id"))!,
                provider: row.required("provider"),
                model: row.required("model"),
                taskClass: ModelTaskClass(rawValue: row.required("task_class"))!,
                inputTokens: Int(row.int("input_tokens")),
                outputTokens: Int(row.int("output_tokens")),
                estimatedCostUSD: row.double("estimated_cost_usd"),
                createdAt: Date(timeIntervalSince1970: row.double("created_at"))
            )
        }
    }

    public func cachedOutput(for key: String) throws -> LLMResponse? {
        guard let row = try db.query("SELECT * FROM llm_cache WHERE cache_key = ?", [.text(key)]).first else {
            return nil
        }
        return LLMResponse(
            text: row.required("output"),
            inputTokens: 0,
            outputTokens: 0,
            provider: row.required("provider"),
            model: row.required("model"),
            raw: nil
        )
    }

    public func saveCache(key: String, response: LLMResponse) throws {
        try db.execute("""
        INSERT OR REPLACE INTO llm_cache VALUES (?, ?, ?, ?, ?)
        """, [
            .text(key),
            .text(response.text),
            .text(response.provider),
            .text(response.model),
            .double(Date().timeIntervalSince1970)
        ])
    }

    public func countsByStatus() throws -> [IdeaStatus: Int] {
        var counts: [IdeaStatus: Int] = [:]
        for row in try db.query("SELECT status, COUNT(*) AS count FROM idea_seeds GROUP BY status") {
            if let status = IdeaStatus(rawValue: row.required("status")) {
                counts[status] = Int(row.int("count"))
            }
        }
        return counts
    }

    public func deleteAllData() throws {
        try db.transaction {
            for table in [
                "llm_cache",
                "llm_usage_records",
                "build_outcomes",
                "prototype_briefs",
                "idea_critiques",
                "ripeness_scores",
                "agent_run_logs",
                "fermentation_runs",
                "fermentation_jobs",
                "idea_connections",
                "source_search",
                "source_items",
                "idea_search",
                "idea_seeds"
            ] {
                try db.execute("DELETE FROM \(table)")
            }
            try db.execute("DELETE FROM app_settings")
        }
    }

    public func usageTotalUSD() throws -> Double {
        let row = try db.query("SELECT COALESCE(SUM(estimated_cost_usd), 0) AS total FROM llm_usage_records").first
        return row?.double("total") ?? 0
    }

    public func usageTotalUSD(since date: Date) throws -> Double {
        let row = try db.query("SELECT COALESCE(SUM(estimated_cost_usd), 0) AS total FROM llm_usage_records WHERE created_at >= ?", [.double(date.timeIntervalSince1970)]).first
        return row?.double("total") ?? 0
    }

    public func loadSchedulerSettings() throws -> SchedulerSettings {
        try loadSetting("scheduler", defaultValue: SchedulerSettings())
    }

    public func saveSchedulerSettings(_ settings: SchedulerSettings) throws {
        try saveSetting("scheduler", settings)
    }

    public func loadProviderSettings() throws -> ProviderSettings {
        try loadSetting("provider", defaultValue: ProviderSettings())
    }

    public func saveProviderSettings(_ settings: ProviderSettings) throws {
        try saveSetting("provider", settings)
    }

    public func loadAutonomyProfile() throws -> AutonomyProfile {
        try loadSetting("autonomy_profile", defaultValue: AutonomyProfile())
    }

    public func saveAutonomyProfile(_ profile: AutonomyProfile) throws {
        try saveSetting("autonomy_profile", profile)
    }

    public func loadScoutMissions() throws -> [ScoutMission] {
        try loadSetting("scout_missions", defaultValue: [])
    }

    public func saveScoutMissions(_ missions: [ScoutMission]) throws {
        try saveSetting("scout_missions", missions)
    }

    public func loadTasteModel() throws -> TasteModel {
        try loadSetting("taste_model", defaultValue: TasteModel())
    }

    public func saveTasteModel(_ model: TasteModel) throws {
        try saveSetting("taste_model", model)
    }

    public func loadCaptureServerConfig() throws -> CaptureServerConfig {
        try loadSetting("capture_server", defaultValue: CaptureServerConfig())
    }

    public func saveCaptureServerConfig(_ config: CaptureServerConfig) throws {
        try saveSetting("capture_server", config)
    }

    private func loadSetting<T: Codable>(_ key: String, defaultValue: T) throws -> T {
        guard let row = try db.query("SELECT value FROM app_settings WHERE key = ?", [.text(key)]).first else {
            return defaultValue
        }
        return (try? JSONSupport.decode(T.self, from: row["value"] ?? nil)) ?? defaultValue
    }

    private func saveSetting<T: Codable>(_ key: String, _ value: T) throws {
        try db.execute("""
        INSERT OR REPLACE INTO app_settings VALUES (?, ?)
        """, [.text(key), .text(try JSONSupport.encode(value))])
    }

    private func ideaBindings(_ idea: IdeaSeed) throws -> [SQLiteValue] {
        [
            .text(idea.id.uuidString),
            .text(idea.title),
            .text(idea.body),
            .double(idea.createdAt.timeIntervalSince1970),
            .double(idea.updatedAt.timeIntervalSince1970),
            .text(idea.status.rawValue),
            .text(idea.stage.rawValue),
            .text(try JSONSupport.encode(idea.sourceIDs.map(\.uuidString))),
            .text(try JSONSupport.encode(idea.manualTags)),
            .text(idea.textHash),
            .text(try JSONSupport.encode(idea.embedding)),
            .double(idea.ripeness),
            .double(idea.novelty),
            .double(idea.feasibility),
            .double(idea.evidence),
            .double(idea.personalResonance),
            .double(idea.timing)
        ]
    }

    private func sourceBindings(_ source: SourceItem) throws -> [SQLiteValue] {
        [
            .text(source.id.uuidString),
            .text(source.type.rawValue),
            .text(source.title),
            .text(source.body),
            .double(source.createdAt.timeIntervalSince1970),
            source.filePath.map(SQLiteValue.text) ?? .null,
            source.url.map(SQLiteValue.text) ?? .null,
            .text(source.extractionStatus.rawValue),
            .text(try JSONSupport.encode(source.linkedIdeaIDs.map(\.uuidString))),
            .bool(source.neverSendToCloud),
            .text(source.textHash),
            .text(try JSONSupport.encode(source.metadata))
        ]
    }

    private func jobBindings(_ job: FermentationJob) throws -> [SQLiteValue] {
        let routeValue: SQLiteValue = try job.modelRoute.map { .text(try JSONSupport.encode($0)) } ?? .null
        return [
            .text(job.id.uuidString),
            job.ideaID.map { .text($0.uuidString) } ?? .null,
            job.sourceID.map { .text($0.uuidString) } ?? .null,
            .text(job.taskClass.rawValue),
            .text(job.status.rawValue),
            .int(Int64(job.retryCount)),
            .double(job.estimatedCostUSD),
            routeValue,
            .text(job.inputHash),
            .double(job.createdAt.timeIntervalSince1970),
            .double(job.updatedAt.timeIntervalSince1970),
            job.scheduledAt.map { .double($0.timeIntervalSince1970) } ?? .null,
            job.completedAt.map { .double($0.timeIntervalSince1970) } ?? .null,
            job.lastError.map(SQLiteValue.text) ?? .null,
            job.retryAfter.map { .double($0.timeIntervalSince1970) } ?? .null,
            job.runID.map { .text($0.uuidString) } ?? .null
        ]
    }

    private func decodeIdea(_ row: [String: String?]) throws -> IdeaSeed {
        let sourceIDs: [String] = try JSONSupport.decode([String].self, from: row["source_ids"] ?? nil)
        return IdeaSeed(
            id: UUID(uuidString: row.required("id"))!,
            title: row.required("title"),
            body: row.required("body"),
            createdAt: Date(timeIntervalSince1970: row.double("created_at")),
            updatedAt: Date(timeIntervalSince1970: row.double("updated_at")),
            status: IdeaStatus(rawValue: row.required("status"))!,
            stage: FermentationStage(rawValue: row.required("stage"))!,
            sourceIDs: sourceIDs.compactMap(UUID.init(uuidString:)),
            manualTags: try JSONSupport.decode([String].self, from: row["manual_tags"] ?? nil),
            textHash: row.required("text_hash"),
            embedding: try JSONSupport.decode([Double].self, from: row["embedding"] ?? nil),
            ripeness: row.double("ripeness"),
            novelty: row.double("novelty"),
            feasibility: row.double("feasibility"),
            evidence: row.double("evidence"),
            personalResonance: row.double("personal_resonance"),
            timing: row.double("timing")
        )
    }

    private func decodeSource(_ row: [String: String?]) throws -> SourceItem {
        let ideaIDs: [String] = try JSONSupport.decode([String].self, from: row["linked_idea_ids"] ?? nil)
        return SourceItem(
            id: UUID(uuidString: row.required("id"))!,
            type: SourceType(rawValue: row.required("type"))!,
            title: row.required("title"),
            body: row.required("body"),
            createdAt: Date(timeIntervalSince1970: row.double("created_at")),
            filePath: row["file_path"] ?? nil,
            url: row["url"] ?? nil,
            extractionStatus: SourceExtractionStatus(rawValue: row.required("extraction_status"))!,
            linkedIdeaIDs: ideaIDs.compactMap(UUID.init(uuidString:)),
            neverSendToCloud: row.int("never_send_to_cloud") == 1,
            textHash: row.required("text_hash"),
            metadata: (try? JSONSupport.decode(SourceMetadata.self, from: row["metadata"] ?? nil)) ?? SourceMetadata()
        )
    }

    private func decodeJob(_ row: [String: String?]) throws -> FermentationJob {
        let route: ModelRoute? = try row["model_route"].flatMap { try JSONSupport.decode(ModelRoute.self, from: $0) }
        return FermentationJob(
            id: UUID(uuidString: row.required("id"))!,
            ideaID: (row["idea_id"] ?? nil).flatMap(UUID.init(uuidString:)),
            sourceID: (row["source_id"] ?? nil).flatMap(UUID.init(uuidString:)),
            taskClass: ModelTaskClass(rawValue: row.required("task_class"))!,
            status: JobStatus(rawValue: row.required("status"))!,
            retryCount: Int(row.int("retry_count")),
            estimatedCostUSD: row.double("estimated_cost_usd"),
            modelRoute: route,
            inputHash: row.required("input_hash"),
            createdAt: Date(timeIntervalSince1970: row.double("created_at")),
            updatedAt: Date(timeIntervalSince1970: row.double("updated_at")),
            scheduledAt: (row["scheduled_at"] ?? nil).map { Date(timeIntervalSince1970: Double($0) ?? 0) },
            completedAt: (row["completed_at"] ?? nil).map { Date(timeIntervalSince1970: Double($0) ?? 0) },
            lastError: row["last_error"] ?? nil,
            retryAfter: (row["retry_after"] ?? nil).map { Date(timeIntervalSince1970: Double($0) ?? 0) },
            runID: (row["run_id"] ?? nil).flatMap(UUID.init(uuidString:))
        )
    }
}

extension Dictionary where Key == String, Value == String? {
    func required(_ key: String) -> String {
        (self[key] ?? nil) ?? ""
    }

    func double(_ key: String) -> Double {
        Double(required(key)) ?? 0
    }

    func int(_ key: String) -> Int64 {
        Int64(required(key)) ?? 0
    }
}
