import SwiftUI

/// The severity of a transient message. The app funnels both successes and errors
/// through `ShellViewModel.errorMessage` (a contract the tests depend on), so the
/// tone is *inferred* from the message text rather than carried as state. Unknown
/// messages default to `.error` — anything we didn't author is assumed to be a real
/// `error.localizedDescription`, so a genuine failure is never shown as benign.
enum ToastTone: Equatable {
    case success, info, warning, error

    var color: Color {
        switch self {
        case .success: IFMTheme.green
        case .info: IFMTheme.blue
        case .warning: IFMTheme.orange
        case .error: IFMTheme.red
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    /// Spoken label for VoiceOver, prepended to the message.
    var accessibilityPrefix: String {
        switch self {
        case .success: "Success"
        case .info: "Notice"
        case .warning: "Warning"
        case .error: "Error"
        }
    }

    /// Non-error tones auto-dismiss; errors stay until the user dismisses them or a
    /// newer message replaces them.
    var autoDismiss: Bool { self != .error }

    /// Pure classifier — unit-tested. Order matters: the most specific buckets are
    /// checked first, and the app-authored positive notices are matched explicitly
    /// so everything unrecognized falls through to `.error`.
    static func classify(_ message: String) -> ToastTone {
        let m = message.lowercased()
        func has(_ keywords: [String]) -> Bool { keywords.contains { m.contains($0) } }

        if has(["no pending notifications", "no pending"]) { return .info }
        if has([
            "already", "needs approval", "need approval", "cap reached", "blocked",
            "remove the", "before approving", "add a ", "add an ", "api key",
            "enable an", "running jobs finish", "before they can pause"
        ]) { return .warning }
        if has([
            "created", "queued", "imported", "generated", "saved",
            "exported", "duplicated", "ready to build", "recorded"
        ]) { return .success }
        return .error
    }
}

/// A non-blocking banner that slides in below the top bar. Replaces the v1 modal
/// `.alert`, which interrupted the operator even for routine successes like
/// "Build plan created".
struct ToastBanner: View {
    var message: String
    var tone: ToastTone
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tone.color)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(IFMTheme.text)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(IFMTheme.muted)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 460, alignment: .leading)
        .background(IFMTheme.panelStrong)
        .clipShape(RoundedRectangle(cornerRadius: IFMRadius.lg, style: .continuous))
        .overlay(alignment: .leading) {
            // A tone-colored spine so severity reads at a glance.
            Rectangle()
                .fill(tone.color)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.vertical, 8)
                .padding(.leading, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: IFMRadius.lg, style: .continuous)
                .stroke(tone.color.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tone.accessibilityPrefix). \(message)")
    }
}
