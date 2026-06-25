import AppKit
import IdeaFermentationCore
import SwiftUI
import UniformTypeIdentifiers

struct EmptyStateCard: View {
    var title: String
    var message: String
    var symbol: String
    var actionTitle: String?
    var accent: Color = IFMTheme.green
    var action: (() -> Void)?

    var body: some View {
        IFMCard(padding: 24) {
            VStack(spacing: 10) {
                SymbolBadge(symbol: symbol, color: accent, size: 54)
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(2)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(IFMTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 190)
            .padding(.vertical, 4)
            .background(IFMTheme.softPanel.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(accent.opacity(0.13)) }
        }
    }
}

struct IdeaCaptureSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Idea").font(.system(size: 24, weight: .bold))
            TextField("Title", text: $model.ideaDraft.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Idea title")
            TextEditor(text: $model.ideaDraft.body)
                .frame(minHeight: 160)
                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                .accessibilityLabel("Idea body")
            TextField("Tags, comma separated", text: $model.ideaDraft.tags)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Idea tags")
            HStack {
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Save Idea") { model.saveIdeaDraft() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.ideaDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.ideaDraft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}

struct SourceCaptureSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Source").font(.system(size: 24, weight: .bold))
            Picker("Type", selection: $model.sourceDraft.type) {
                ForEach(SourceType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            TextField("Title", text: $model.sourceDraft.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Source title")
            TextField("URL (optional)", text: $model.sourceDraft.url)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Source URL")
            TextEditor(text: $model.sourceDraft.body)
                .frame(minHeight: 140)
                .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                .accessibilityLabel("Source text")
            Toggle("Never send this source to cloud models", isOn: $model.sourceDraft.neverSendToCloud)
            HStack {
                Button("Import File…") { chooseSourceFile(model: model) }
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Save Source") { model.saveSourceDraft() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.sourceDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.sourceDraft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.sourceDraft.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540)
    }
}

struct ProviderKeysSheet: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider Keys").font(.system(size: 24, weight: .bold))
            Text("Keys are stored in macOS Keychain. Blank fields leave existing keys unchanged.")
                .font(.caption)
                .foregroundStyle(IFMTheme.muted)
            SecureField("Gemini API key", text: $model.keyDraft.gemini)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Gemini API key")
            SecureField("Z.ai API key", text: $model.keyDraft.zai)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Z.ai API key")
            SecureField("Kimi or Moonshot API key", text: $model.keyDraft.kimi)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Kimi API key")
            SecureField("OpenAI API key", text: $model.keyDraft.openAI)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("OpenAI API key")
            SecureField("Claude or Anthropic API key", text: $model.keyDraft.anthropic)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Claude API key")
            SecureField("Firecrawl API key", text: $model.keyDraft.firecrawl)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Firecrawl API key")
            SecureField("OpenAI-compatible fallback key", text: $model.keyDraft.openAICompatible)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("OpenAI-compatible fallback API key")
            Divider()
            TextField("Fallback provider label", text: $model.keyDraft.fallbackLabel)
                .textFieldStyle(.roundedBorder)
            TextField("Fallback base URL", text: $model.keyDraft.fallbackBaseURL)
                .textFieldStyle(.roundedBorder)
            TextField("Fallback model name", text: $model.keyDraft.fallbackModel)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Input $ / 1M tokens", text: $model.keyDraft.fallbackInputCost)
                    .textFieldStyle(.roundedBorder)
                TextField("Output $ / 1M tokens", text: $model.keyDraft.fallbackOutputCost)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                Button("Save Keys") { model.saveKeys() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 560)
    }
}

struct SettingsPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var confirmingReset = false

    var body: some View {
        PageScaffold(title: "Settings", subtitle: "Provider keys, local data, and app controls.", symbol: "gearshape", accent: IFMTheme.slate) {
            VStack(alignment: .leading, spacing: 16) {
                IFMCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("API Keys").font(.headline)
                        keyRow("Gemini", hasKey: model.hasKey(.gemini))
                        keyRow("Z.ai / GLM", hasKey: model.hasKey(.zai))
                        keyRow("Kimi / Moonshot", hasKey: model.hasKey(.kimi))
                        keyRow("OpenAI", hasKey: model.hasKey(.openAI))
                        keyRow("Claude / Anthropic", hasKey: model.hasKey(.anthropic))
                        keyRow("Firecrawl web search", hasKey: model.hasKey(.firecrawl))
                        keyRow("OpenAI-compatible fallback", hasKey: model.hasKey(.openAICompatible))
                        Text("Fallback: \(model.providerSettings.fallbackProviderLabel) / \(model.providerSettings.fallbackModelName)")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                        Button("Manage Keys") { model.prepareKeyDraft() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if let server = model.captureServer {
                    BrowserConnectorCard(server: server, model: model)
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Local Data").font(.headline)
                        Text(model.store.databaseURL.path)
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        HStack {
                            Button("Reveal Database") {
                                NSWorkspace.shared.activateFileViewerSelecting([model.store.databaseURL])
                            }
                            Button("Reset All Data", role: .destructive) { confirmingReset = true }
                        }
                    }
                }
            }
        } rail: {
            PrivacySummaryRail(model: model)
        }
        .confirmationDialog(
            "Reset all local Idea Fermentation Machine data?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset All Data", role: .destructive) { model.resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes local ideas, sources, jobs, logs, patterns, and settings from this app database. API keys in Keychain are not deleted.")
        }
    }

    private func keyRow(_ title: String, hasKey: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(hasKey ? "Configured" : "Missing", systemImage: hasKey ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(hasKey ? IFMTheme.green : IFMTheme.red)
        }
        .font(.system(size: 14))
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background((hasKey ? IFMTheme.green : IFMTheme.red).opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md))
    }
}

struct BrowserConnectorCard: View {
    @ObservedObject var server: CaptureServer
    @ObservedObject var model: ShellViewModel
    @State private var revealToken = false

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Browser Connector", systemImage: "link.badge.plus").font(.headline)
                    Spacer()
                    Label(statusText, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(server.isRunning ? IFMTheme.green : IFMTheme.gray)
                }
                Text("Save any page from Chrome straight into Sources — auto-categorized, tagged, and linked to related ideas. Pair the extension once with the token below.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)

                Toggle("Enable connector", isOn: Binding(
                    get: { model.captureServerEnabled },
                    set: { model.setCaptureServerEnabled($0) }
                ))
                .font(.system(size: 13))

                infoRow("Address", server.isRunning ? "127.0.0.1:\(server.activePort)" : "Not running")

                HStack(spacing: 8) {
                    Text("Token").foregroundStyle(IFMTheme.muted)
                    Spacer()
                    Text(revealToken ? server.token : Self.masked(server.token))
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Button(revealToken ? "Hide" : "Reveal") { revealToken.toggle() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .accessibilityLabel(revealToken ? "Hide connector token" : "Reveal connector token")
                }
                .font(.caption)

                HStack {
                    Button("Copy Token") { model.copyCaptureToken() }
                    Button("Copy Pairing Info") { model.copyCapturePairingInfo() }
                    Spacer()
                    Button("Regenerate") { model.regenerateCaptureToken() }
                        .tint(IFMTheme.orange)
                        .accessibilityLabel("Regenerate connector token")
                }
                .font(.caption)

                if let error = server.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(IFMTheme.red)
                }
                Text("In Chrome: load the ChromeExtension folder (Developer mode), open its options, and paste the token. The app keeps running with its window closed so saving always works.")
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
            }
        }
    }

    private var statusText: String {
        server.isRunning ? "Running" : (model.captureServerEnabled ? "Starting" : "Off")
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(IFMTheme.muted)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption)
    }

    private static func masked(_ token: String) -> String {
        guard token.count > 10 else { return "••••••••" }
        return "\(token.prefix(4))••••••••\(token.suffix(4))"
    }
}

struct AutonomyPage: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        PageScaffold(title: "Autonomy", subtitle: "Teach the scout what to look for, then let it create source-backed idea candidates.", symbol: "sparkle.magnifyingglass", accent: IFMTheme.green) {
            VStack(alignment: .leading, spacing: 16) {
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Autonomous Mode").font(.headline)
                                Text("Runs best-effort scouting and saves candidates for review.")
                                    .font(.caption)
                                    .foregroundStyle(IFMTheme.muted)
                            }
                            Spacer()
                            Toggle("", isOn: $model.autonomyProfile.isEnabled)
                                .labelsHidden()
                                .accessibilityLabel("Autonomous mode")
                                .onChange(of: model.autonomyProfile.isEnabled) { _, _ in model.persistAutonomyConfiguration() }
                        }
                        Toggle("Allow public web scouting", isOn: $model.autonomyProfile.allowWebScouting)
                            .onChange(of: model.autonomyProfile.allowWebScouting) { _, _ in model.persistAutonomyConfiguration() }
                        Toggle("Require approval before build handoff", isOn: $model.autonomyProfile.requireApprovalBeforeBuildHandoff)
                            .onChange(of: model.autonomyProfile.requireApprovalBeforeBuildHandoff) { _, _ in model.persistAutonomyConfiguration() }
                    }
                }

                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Taste Profile").font(.headline)
                        TextEditor(text: $model.autonomyProfile.tasteNotes)
                            .frame(minHeight: 76)
                            .overlay { RoundedRectangle(cornerRadius: IFMRadius.md).stroke(IFMTheme.border) }
                            .accessibilityLabel("Taste notes")
                        TextField("Goals", text: $model.autonomyProfile.goals)
                            .textFieldStyle(.roundedBorder)
                        TextField("Watch topics, comma separated", text: $model.autonomyProfile.watchTopics)
                            .textFieldStyle(.roundedBorder)
                        TextField("Excluded topics", text: $model.autonomyProfile.excludedTopics)
                            .textFieldStyle(.roundedBorder)
                        TextField("Preferred outputs", text: $model.autonomyProfile.preferredOutputs)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Spacer()
                            Button("Save Profile") { model.persistAutonomyConfiguration() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }

                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Scout Missions").font(.headline)
                            Spacer()
                            Button {
                                Task { await model.runAutonomousScout() }
                            } label: {
                                HStack(spacing: 6) {
                                    if model.isRunningScout { ProgressView().controlSize(.small) }
                                    Text(model.isRunningScout ? "Scouting…" : "Run Scout Now")
                                }
                            }
                            .disabled(model.isRunningScout || !model.autonomyProfile.isEnabled)
                            .buttonStyle(.borderedProminent)
                        }
                        HStack {
                            TextField("Mission title", text: $model.scoutMissionDraft.title)
                                .textFieldStyle(.roundedBorder)
                            TextField("Query", text: $model.scoutMissionDraft.query)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") { model.addScoutMission() }
                                .disabled(model.scoutMissionDraft.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if model.scoutMissions.isEmpty {
                            Text("Add a mission like \"AI-native macOS utilities\" or run the scout to create a default mission from your watch topics.")
                                .font(.caption)
                                .foregroundStyle(IFMTheme.muted)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(model.scoutMissions) { mission in
                                ScoutMissionRow(
                                    mission: mission,
                                    toggle: { model.toggleScoutMission(mission) },
                                    delete: { model.deleteScoutMission(mission) }
                                )
                                Divider()
                            }
                        }
                    }
                }
            }
        } rail: {
            AutonomyRail(model: model)
        }
    }
}

struct ScoutMissionRow: View {
    var mission: ScoutMission
    var toggle: () -> Void
    var delete: () -> Void
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            SymbolBadge(symbol: mission.isEnabled ? "antenna.radiowaves.left.and.right" : "pause.circle", color: mission.isEnabled ? IFMTheme.green : IFMTheme.gray, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(mission.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(mission.query).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(1)
                HStack(spacing: 8) {
                    Text(mission.lastRunAt.map { "Last ran \(Self.dateFormatter.string(from: $0))" } ?? "Not run yet")
                    Text("Every \(mission.cadenceHours)h")
                    Text(nextRunText)
                        .foregroundStyle(isDue ? IFMTheme.green : IFMTheme.muted)
                }
                .font(.caption2)
                .foregroundStyle(IFMTheme.muted)
            }
            Spacer()
            Button(mission.isEnabled ? "Pause" : "Enable", action: toggle)
            Button(role: .destructive, action: {
                confirmingDelete = true
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete mission")
            .accessibilityLabel("Delete mission")
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Delete “\(mission.title)”?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Mission", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The scout mission will stop running. Existing ideas and sources remain.")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var isDue: Bool {
        mission.isEnabled && mission.lastRunAt.map { Date(timeInterval: Double(max(1, mission.cadenceHours) * 60 * 60), since: $0) <= Date() } ?? true
    }

    private var nextRunText: String {
        guard mission.isEnabled else { return "Paused" }
        guard let lastRunAt = mission.lastRunAt else { return "Due now" }
        let next = Date(timeInterval: Double(max(1, mission.cadenceHours) * 60 * 60), since: lastRunAt)
        return next <= Date() ? "Due now" : "Next \(Self.dateFormatter.string(from: next))"
    }
}

struct AutonomyRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Agent Loop").font(.system(size: 18, weight: .bold))
            railStat("Mode", model.autonomyProfile.isEnabled ? "On" : "Off", model.autonomyProfile.isEnabled ? IFMTheme.green : IFMTheme.gray)
            railStat("Missions", "\(model.scoutMissions.filter(\.isEnabled).count)", IFMTheme.green)
            railStat("Scout logs", "\(model.logs.filter { $0.agentName == "Scout Agent" }.count)", IFMTheme.blue)
            IFMCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Stack").font(.caption.bold())
                    searchRow("Firecrawl", model.hasKey(.firecrawl))
                    searchRow("OpenAI web", model.hasKey(.openAI))
                    HStack {
                        Text("Public fallback")
                        Spacer()
                        Text("Always")
                            .font(.caption.bold())
                            .foregroundStyle(IFMTheme.green)
                    }
                    .font(.caption)
                }
            }
            IFMCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What it does").font(.caption.bold())
                    Text("Find signals, save sources, create a linked candidate idea, then queue a local ripeness pass.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                }
            }
        }
    }

    private func searchRow(_ title: String, _ configured: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(configured ? "Ready" : "No key")
                .font(.caption.bold())
                .foregroundStyle(configured ? IFMTheme.green : IFMTheme.muted)
        }
        .font(.caption)
    }

    private func railStat(_ title: String, _ value: String, _ color: Color) -> some View {
        IFMCard(padding: 12) {
            HStack {
                Text(title)
                Spacer()
                Text(value).font(.headline).foregroundStyle(color)
            }
        }
    }
}

struct CostCenterPage: View {
    @ObservedObject var model: ShellViewModel
    @State private var confirmingApproveAll = false

    var body: some View {
        PageScaffold(title: "Cost Center", subtitle: "Spend, queue, approvals, and routing.", symbol: "chart.pie", accent: IFMTheme.blue) {
            VStack(spacing: 16) {
                let pendingPreview = model.pendingCloudPreview
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    metric("Total Spend", String(format: "$%.4f", model.metrics.totalSpend), IFMTheme.green)
                    metric("Pending Jobs", "\(model.metrics.pendingJobs)", IFMTheme.orange)
                    metric("Needs Approval", "\(model.metrics.approvalJobs)", IFMTheme.red)
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Queue").font(.headline)
                        if model.jobs.isEmpty {
                            Text("No jobs queued. Run local fermentation or queue a cloud loop from the incubator.")
                                .foregroundStyle(IFMTheme.muted)
                        } else {
                            ForEach(model.jobs.prefix(20)) { job in
                                JobQueueRow(model: model, job: job)
                                Divider()
                            }
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                Button("Queue Cloud Loop") { model.queueFermentationLoop() }
                                Button("Approve All…") { confirmingApproveAll = true }
                                    .disabled(model.metrics.approvalJobs == 0)
                                Button { model.runNextCloudJob() } label: {
                                    HStack(spacing: 6) {
                                        if model.isRunningJob { ProgressView().controlSize(.small) }
                                        Text(model.isRunningJob ? "Running…" : "Run Next Cloud Job")
                                    }
                                }
                                .disabled(model.isRunningJob)
                            }
                        }
                        .scrollIndicators(.never)
                    }
                }
                if let pendingPreview {
                    CloudPayloadPreviewCard(preview: pendingPreview) {
                        model.approveJob(pendingPreview.job)
                    }
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scheduler").font(.headline)
                        Label("Runs while this app is open", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                        Toggle("Allow capped auto-cloud", isOn: Binding(
                            get: { model.schedulerSettings.cloudAutoRun },
                            set: { enabled in
                                var settings = model.schedulerSettings
                                settings.cloudAutoRun = enabled
                                model.updateScheduler(settings)
                            }
                        ))
                        HStack {
                            Text("Local cadence")
                            Spacer()
                            Text("\(model.schedulerSettings.localCadenceMinutes) min")
                                .foregroundStyle(IFMTheme.muted)
                        }
                        capStepper(
                            title: "Daily cap",
                            value: model.schedulerSettings.dailySpendCapUSD,
                            step: 0.50,
                            update: { model.updateDailySpendCap(String($0)) }
                        )
                        capStepper(
                            title: "Monthly cap",
                            value: model.schedulerSettings.monthlySpendCapUSD,
                            step: 5,
                            update: { model.updateMonthlySpendCap(String($0)) }
                        )
                        Button("Run Scheduler Now") { model.runSchedulerNow() }
                            .buttonStyle(.borderedProminent)
                    }
                    .font(.system(size: 14))
                }
            }
            .confirmationDialog(
                "Approve all \(model.metrics.approvalJobs) cloud job(s)?",
                isPresented: $confirmingApproveAll,
                titleVisibility: .visible
            ) {
                Button("Approve All Cloud Jobs", role: .destructive) { model.approveAllJobs() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Review the payload preview first. Never-send sources remain blocked.")
            }
        } rail: {
            RunHistoryRail(model: model)
        }
    }

    private func capStepper(title: String, value: Double, step: Double, update: @escaping (Double) -> Void) -> some View {
        Stepper(value: Binding(
            get: { value },
            set: { update(max(0, $0)) }
        ), in: 0...10_000, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "$%.2f", value))
                    .foregroundStyle(IFMTheme.muted)
                    .monospacedDigit()
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(value).font(.system(size: 28, weight: .bold)).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(IFMTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct JobQueueRow: View {
    @ObservedObject var model: ShellViewModel
    var job: FermentationJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                SymbolBadge(symbol: job.estimatedCostUSD > 0 ? "cloud" : "desktopcomputer", color: color, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.taskClass.rawValue).font(.system(size: 13, weight: .semibold))
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(IFMTheme.muted)
                        .lineLimit(1)
                }
                Spacer()
                Pill(text: job.status.rawValue, color: color)
                Text(String(format: "$%.4f", job.estimatedCostUSD))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(IFMTheme.muted)
                    .frame(width: 64, alignment: .trailing)
                controls
            }
            if let lastError = job.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.orange)
                    .lineLimit(2)
                    .padding(.leading, 38)
            }
        }
        .padding(.vertical, 4)
    }

    private var detailText: String {
        var parts = [job.ideaID != nil ? "Idea job" : job.sourceID != nil ? "Source job" : "System job"]
        if let route = job.modelRoute {
            parts.append("\(route.provider) / \(route.model)")
        }
        if job.retryCount > 0 {
            parts.append("retry \(job.retryCount)")
        }
        return parts.joined(separator: " • ")
    }

    @ViewBuilder
    private var controls: some View {
        switch job.status {
        case .needsApproval:
            Button("Approve") { model.approveJob(job) }
                .buttonStyle(.bordered)
        case .pending:
            Button("Pause") { model.pauseJob(job) }
                .buttonStyle(.bordered)
        case .paused:
            Button("Resume") { model.resumeJob(job) }
                .buttonStyle(.borderedProminent)
        case .failed:
            Button("Retry") { model.retryJob(job) }
                .buttonStyle(.bordered)
        case .running:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small)
                Text("Running")
                    .font(.caption.bold())
                    .foregroundStyle(IFMTheme.blue)
            }
        case .complete:
            EmptyView()
        }
    }

    private var color: Color {
        switch job.status {
        case .needsApproval: IFMTheme.red
        case .failed, .paused: IFMTheme.orange
        case .running: IFMTheme.blue
        case .complete: IFMTheme.gray
        case .pending: IFMTheme.green
        }
    }
}

struct CloudPayloadPreviewCard: View {
    var preview: PendingCloudPreview
    var approve: () -> Void

    var body: some View {
        IFMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cloud Payload Preview").font(.headline)
                        Text("\(preview.payload.taskClass.rawValue) • \(preview.payload.characterCount) characters")
                            .font(.caption)
                            .foregroundStyle(IFMTheme.muted)
                    }
                    Spacer()
                    Pill(text: String(format: "$%.4f", preview.job.estimatedCostUSD), color: preview.job.estimatedCostUSD > 0 ? IFMTheme.orange : IFMTheme.green)
                }
                if preview.payload.blockedSourceTitles.isEmpty {
                    Label("No never-send sources included.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.green)
                } else {
                    Label("Blocked: \(preview.payload.blockedSourceTitles.joined(separator: ", "))", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.orange)
                        .lineLimit(2)
                }
                ScrollView {
                    Text(preview.payload.payload.isEmpty ? "Nothing can be sent for this job because all material is blocked." : preview.payload.payload)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(IFMTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 120, maxHeight: 180)
                .background(IFMTheme.scrim.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: IFMRadius.md, style: .continuous))
                HStack {
                    Text(preview.payload.maySend ? "Review before approving cloud synthesis." : "Cloud approval is blocked by privacy settings.")
                        .font(.caption)
                        .foregroundStyle(IFMTheme.muted)
                    Spacer()
                    Button("Approve This Job", action: approve)
                        .buttonStyle(.borderedProminent)
                        .disabled(!preview.payload.maySend)
                }
            }
        }
    }
}

struct PrivacyCenterPage: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        PageScaffold(title: "Privacy Center", subtitle: "What stays local and what can be sent to providers.", symbol: "lock.shield", accent: IFMTheme.green) {
            VStack(alignment: .leading, spacing: 16) {
                let pendingPreview = model.pendingCloudPreview
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    privacyStat("Local records", "\(model.ideas.count + model.sources.count)")
                    privacyStat("Never-send", "\(model.sources.filter(\.neverSendToCloud).count)")
                    privacyStat("Cloud spend", String(format: "$%.4f", model.metrics.totalSpend))
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Local-first defaults").font(.headline)
                        privacyBullet("Ideas, sources, embeddings, queues, logs, and cache live on this Mac.")
                        privacyBullet("API keys are stored in macOS Keychain.")
                        privacyBullet("Sources marked never-send are excluded from cloud payload previews.")
                    }
                }
                if let pendingPreview {
                    CloudPayloadPreviewCard(preview: pendingPreview) {
                        model.approveJob(pendingPreview.job)
                    }
                }
                IFMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Never-send sources").font(.headline)
                        let blocked = model.sources.filter(\.neverSendToCloud)
                        if blocked.isEmpty {
                            Text("No source is currently blocked from cloud use.")
                                .foregroundStyle(IFMTheme.muted)
                        } else {
                            ForEach(blocked) { source in
                                PrivacyBlockedSourceRow(
                                    source: source,
                                    allowCloudUse: { model.toggleNeverSend(source) },
                                    open: { model.openSource(source) }
                                )
                                Divider().opacity(0.45)
                            }
                        }
                    }
                }
            }
        } rail: {
            PrivacySummaryRail(model: model)
        }
    }

    private func privacyStat(_ title: String, _ value: String) -> some View {
        IFMCard(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(IFMTheme.green)
                Text(title).font(.caption).foregroundStyle(IFMTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func privacyBullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(IFMTheme.green)
    }
}

struct PrivacyBlockedSourceRow: View {
    var source: SourceItem
    var allowCloudUse: () -> Void
    var open: () -> Void
    @State private var confirmingAllow = false

    var body: some View {
        HStack(spacing: 10) {
            SymbolBadge(symbol: "lock.fill", color: IFMTheme.orange, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(source.type.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(IFMTheme.muted)
                Text(source.body.isEmpty ? "No extracted text." : source.body)
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
            Button("Open", action: open)
                .buttonStyle(.bordered)
            Button("Allow Cloud Use") { confirmingAllow = true }
                .buttonStyle(.borderedProminent)
                .tint(IFMTheme.green)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Allow cloud use for \(source.title)?",
            isPresented: $confirmingAllow,
            titleVisibility: .visible
        ) {
            Button("Allow Cloud Use", action: allowCloudUse)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Future payload previews may include this source. You can mark it never-send again from Sources.")
        }
    }
}

struct RunHistoryRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Run History").font(.system(size: 18, weight: .bold))
            if model.logs.isEmpty {
                Text("No agent runs yet.")
                    .font(.caption)
                    .foregroundStyle(IFMTheme.muted)
            } else {
                ForEach(model.logs.prefix(8)) { log in
                    IFMCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(log.agentName).font(.caption.bold())
                            Text(log.output).font(.caption).foregroundStyle(IFMTheme.muted).lineLimit(3)
                            Text(log.modelUsed).font(.caption2).foregroundStyle(IFMTheme.slate)
                        }
                    }
                }
            }
        }
    }
}

struct PrivacySummaryRail: View {
    @ObservedObject var model: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy Summary").font(.system(size: 18, weight: .bold))
            stat("Ideas", "\(model.ideas.count)")
            stat("Sources", "\(model.sources.count)")
            stat("Never-send", "\(model.sources.filter(\.neverSendToCloud).count)")
            stat("Cached model outputs", "\(model.logs.count)")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        IFMCard(padding: 12) {
            HStack {
                Text(title)
                Spacer()
                Text(value).font(.headline)
            }
        }
    }
}

@MainActor
func chooseSourceFile(model: ShellViewModel) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = [.image, .text, .plainText, .pdf, .json, .commaSeparatedText]
    if panel.runModal() == .OK {
        for url in panel.urls {
            model.importFile(url: url)
        }
        model.activeSheet = nil
    }
}
