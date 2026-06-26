import Foundation

/// The single, canonical answer to "who am I advising?" for cloud reasoning.
///
/// The app learns the builder five different ways — a token model, an embedding
/// manifold, a distilled portrait, a declared profile, and the scout's derived focus.
/// Most of those are *local-scoring* signals with distinct jobs, so they rightly stay
/// separate. But every cloud agent (deep critique, the scout, portfolio synthesis) needs
/// the same small thing: a short, faithful description of the builder. Before this, each
/// agent hand-rolled its own partial view — the critic saw only the distilled portrait,
/// the scout saw notes + goals + avoid, portfolio saw goals + notes — so the model
/// reasoned about a *different* builder depending on which agent asked. `BuilderContext`
/// composes the declared profile and the distilled portrait into ONE block every cloud
/// agent reads, so the builder the model sees is identical everywhere.
public enum BuilderContext {
    /// A labelled block describing the builder, or "" when nothing is known (so callers
    /// can append it unconditionally). Combines the builder's *declared* intent (goals,
    /// taste notes, topics to avoid) with the taste *portrait* distilled from real
    /// decisions. Only builder-level preferences go here — never idea content — so it is
    /// always safe to include in a cloud prompt.
    public static func promptBlock(profile: AutonomyProfile?, taste: TasteProfile?) -> String {
        var lines: [String] = []
        if let goals = profile?.goals, !goals.isEmpty { lines.append("Goals: \(goals)") }
        if let notes = profile?.tasteNotes, !notes.isEmpty { lines.append("Taste notes: \(notes)") }
        if let avoid = profile?.excludedTopics, !avoid.isEmpty { lines.append("Avoid: \(avoid)") }
        if let learned = taste?.promptContext, !learned.isEmpty {
            lines.append("Learned taste (distilled from real decisions):\n\(learned)")
        }
        guard !lines.isEmpty else { return "" }
        return "The builder you are advising:\n" + lines.joined(separator: "\n")
    }

    /// The builder block followed by a blank-line separator, ready to prepend to an agent's
    /// own role/instruction prompt. Empty when nothing is known.
    public static func promptPrefix(profile: AutonomyProfile?, taste: TasteProfile?) -> String {
        let block = promptBlock(profile: profile, taste: taste)
        return block.isEmpty ? "" : block + "\n\n"
    }
}
