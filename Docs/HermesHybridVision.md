# Idea Fermentation Machine — Hermes Hybrid Vision

## Core Reframe

Idea Fermentation Machine should become a local-first autonomous thinking agent, not just an idea/bookmark manager. It should capture what Chris cares about, watch the outside world, synthesize new ideas, generate mockups and prototype briefs, and let Chris approve which futures deserve build energy.

## Product Promise

- Capture raw material from Chris and the world.
- Learn Chris's taste, goals, constraints, and recurring interests.
- Autonomously research news, products, apps, repos, papers, markets, and communities.
- Generate original idea seeds and source-backed hypotheses.
- Ferment ideas through evidence, contradiction, scoring, and synthesis.
- Produce mockups, briefs, and build prompts.
- Let Chris approve, reject, merge, pause, or send ideas to Codex/Claude Code for implementation.

## Hybrid Model

- Current app:
  - Local idea/source database.
  - Search, import, scoring, queue, provider, cost, privacy, and tabbed workflow.
- Hermes-inspired layer:
  - Persistent agent memory.
  - Self-improving skills learned from Chris's approvals/rejections.
  - Scheduled autonomous work.
  - Research/browser/tool use.
  - Multi-agent roles.
  - Human approval gates.
- Future app:
  - A personal autonomous idea foundry.

## Hermes Reference Points

- Primary reference: https://github.com/NousResearch/hermes-agent
- Useful companion direction:
  - Desktop/web companion surfaces for monitoring autonomous work.
  - Persistent memory plus session search.
  - Skills that can be created from repeated workflows.
  - Cron-style scheduled jobs.
  - Tool/provider registries for web search, browser work, images, files, and model routing.
  - Subagent delegation and isolated workstreams.
  - Redaction, usage pricing, and guardrails around tool execution.

## Autonomous Loops

- Daily scout:
  - Search latest news, launches, apps, repos, papers, and trend signals around Chris's interests.
  - Save sources locally with provenance.
  - Generate idea candidates.
- Fermentation loop:
  - Link new sources to existing ideas.
  - Find contradictions and evidence gaps.
  - Re-score ripeness.
  - Propose next experiment.
- Taste loop:
  - Learn from approvals, archives, edits, and builds.
  - Update Chris's taste profile.
  - Improve future idea generation.
- Build loop:
  - Turn approved ready ideas into prototype briefs.
  - Generate mockups.
  - Draft implementation prompts.
  - Hand off to Codex or Claude Code.

## Agent Roles

- Scout Agent:
  - Monitors external sources and finds raw material.
- Synthesizer Agent:
  - Turns raw material into original ideas.
- Critic Agent:
  - Finds flaws, contradictions, risks, and missing evidence.
- Connector Agent:
  - Links ideas, sources, people, markets, and past patterns.
- Taste Agent:
  - Learns Chris's preferences and rejects low-fit ideas earlier.
- Prototype Agent:
  - Creates build briefs, mockups, and implementation handoffs.
- Curator Agent:
  - Prunes stale ideas, merges duplicates, and highlights what changed.

## Required UX

- Mode switch:
  - Manual Mode for direct capture, sorting, scoring, and build decisions.
  - Autonomous Mode for scheduled scouting, generation, linking, critique, and briefs.
- Autonomous Mode dashboard:
  - What the app did while Chris was away.
  - New ideas proposed.
  - Sources found.
  - Connections made.
  - Decisions needed.
- Idea Detail workspace:
  - Evidence, contradictions, source trail, graph, brief, mockups, and build handoff.
- Approval Inbox:
  - Approve, reject, merge, pause, request deeper research, or send to builder.
- Agent Activity log:
  - Every autonomous action, source, cost, payload, and decision.
- Taste Profile:
  - Editable model of what Chris wants to think about and build.
- Scout Briefs:
  - Configurable research missions such as "AI-native macOS utilities", "ambient memory", or "apps people are complaining about".
- Build Handoff:
  - Export a ready idea to Codex or Claude Code with sources, mockups, implementation constraints, and acceptance criteria.

## Stage Behavior

- Inbox:
  - Manual: Chris captures notes, screenshots, links, PDFs, and raw thoughts.
  - Autonomous: Scout Agent finds sources and proposes seeds with provenance.
- Fermenting:
  - Manual: Chris edits tags, adds context, and asks for connections.
  - Autonomous: Connector and Synthesizer agents link sources, dedupe, summarize, and generate idea variants.
- Ripening:
  - Manual: Chris reviews evidence, contradictions, and experiments.
  - Autonomous: Critic Agent tests demand, competition, novelty, technical feasibility, and strategic fit.
- Ready:
  - Manual: Chris approves build plans and selects ideas.
  - Autonomous: Prototype Agent creates briefs, mockups, and build prompts.
- Archive:
  - Manual: Chris kills, pauses, merges, or resurrects ideas.
  - Autonomous: Curator Agent extracts lessons and updates taste/pattern memory.

## Build Phases

- Phase 1: Autonomous profile.
  - Add editable taste, goals, watchlist topics, excluded topics, preferred app categories, and build constraints.
- Phase 2: Scout loop.
  - Add scheduled web/repo/news/product research jobs that save source-backed candidates.
- Phase 3: Agent workbench.
  - Add approval inbox, agent activity ledger, payload preview, and per-action undo.
- Phase 4: Idea detail workspace.
  - Add evidence graph, contradiction list, source trail, ripeness history, and prototype brief.
- Phase 5: Mockup and build handoff.
  - Generate screen concepts and export implementation packets for Codex/Claude Code.
- Phase 6: Learning loop. **(implemented)**
  - A local, online-learned `TasteModel` updates per-theme weights from the
    operator's own decisions: marking Ready / building an idea reinforces its
    themes (+), archiving or deleting an unripe idea suppresses them (−). The
    local fermentation pass folds the resulting bounded affinity into resonance,
    so scoring self-tunes toward what the operator actually commits to. An
    untrained model is a strict no-op. Surfaced + resettable in Autonomy →
    Learned Taste.
  - **Build-outcome loop:** recording what happened when an idea was taken to build
    (shipped / built / abandoned / flopped + a lesson note) is the strongest signal —
    it reinforces the taste model *harder* than a mark-ready, composts the idea into
    the Archive with its real outcome, and feeds the cloud-synthesis memory digest as
    a lead lesson. Closes "learn from successful builds."
  - **Scout-brief self-tuning:** a derived `ScoutFocus` (focus themes + avoid themes,
    weighted by build outcomes > ready/archive decisions > learned taste) augments
    each mission's search query toward the operator's proven lanes, filters out
    abandoned-lane signals, and biases the synthesis prompt. So the scout doesn't just
    *score* and *synthesize* better — it *hunts* better. Surfaced in Autonomy → Scout
    Focus. Closes "update scout briefs from the learning signal."

The full Hermes learning loop is now closed end to end: capture → ferment →
semantic scoring → build → outcome → taste model + agent memory + scout focus →
sharper hunting, scoring, and synthesis next cycle.

## Guardrails

- Local-first by default.
- BYOK cloud only.
- Never-send sources respected.
- Payload preview before cloud or build handoff.
- Spend caps and approval thresholds.
- Research source provenance required.
- No autonomous irreversible writes outside the app without approval.

## North Star

The app should feel like a quiet AI research partner that wakes up before Chris, scans the frontier, thinks with his taste, brings back thoughtful possibilities, and helps turn the best ones into real software.
