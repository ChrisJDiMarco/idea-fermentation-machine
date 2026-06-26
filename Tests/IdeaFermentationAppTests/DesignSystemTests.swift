import AppKit
import SwiftUI
import Testing
@testable import IdeaFermentationApp

@MainActor
@Suite("Design tokens")
struct ThemeTokenTests {
    /// Resolves an adaptive SwiftUI `Color` into concrete sRGB components for a
    /// specific appearance, so we can assert dark mode actually inverts.
    private func rgba(_ color: Color, appearance name: NSAppearance.Name) -> (r: Double, g: Double, b: Double, a: Double)? {
        let nsColor = NSColor(color)
        guard let appearance = NSAppearance(named: name) else { return nil }
        var result: (Double, Double, Double, Double)?
        appearance.performAsCurrentDrawingAppearance {
            if let srgb = nsColor.usingColorSpace(.sRGB) {
                result = (Double(srgb.redComponent), Double(srgb.greenComponent), Double(srgb.blueComponent), Double(srgb.alphaComponent))
            }
        }
        return result.map { ($0.0, $0.1, $0.2, $0.3) }
    }

    private func luminance(_ c: (r: Double, g: Double, b: Double, a: Double)) -> Double {
        0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    @Test func everyTokenResolvesInLightAndDark() throws {
        #expect(!IFMTheme.allTokens.isEmpty)
        for token in IFMTheme.allTokens {
            #expect(rgba(token.color, appearance: .aqua) != nil, "\(token.name) should resolve in light")
            #expect(rgba(token.color, appearance: .darkAqua) != nil, "\(token.name) should resolve in dark")
        }
    }

    @Test func canvasAndTextInvertBetweenAppearances() throws {
        let canvasLight = try #require(rgba(IFMTheme.canvas, appearance: .aqua))
        let canvasDark = try #require(rgba(IFMTheme.canvas, appearance: .darkAqua))
        let textLight = try #require(rgba(IFMTheme.text, appearance: .aqua))
        let textDark = try #require(rgba(IFMTheme.text, appearance: .darkAqua))

        // Canvas is bright in light and dark in dark; text is the mirror image.
        #expect(luminance(canvasLight) > 0.8)
        #expect(luminance(canvasDark) < 0.25)
        #expect(luminance(textLight) < 0.25)
        #expect(luminance(textDark) > 0.8)
    }

    @Test func textHasStrongContrastAgainstCanvasInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let canvas = try #require(rgba(IFMTheme.canvas, appearance: name))
            let text = try #require(rgba(IFMTheme.text, appearance: name))
            #expect(abs(luminance(canvas) - luminance(text)) > 0.5, "text/canvas contrast too low in \(name.rawValue)")
        }
    }
}

@Suite("Categorical accents")
struct CategoricalAccentTests {
    @Test func accentSeriesIsStableAndWraps() {
        #expect(IFMTheme.categorical.count == 6)
        // Same index → same color everywhere (one ordered series, no per-screen drift).
        #expect(IFMTheme.accent(0) == IFMTheme.categorical[0])
        #expect(IFMTheme.accent(6) == IFMTheme.accent(0))   // wraps
        #expect(IFMTheme.accent(-1) == IFMTheme.categorical[5]) // negative wraps safely
        #expect(IFMRadius.xs == 4)
    }
}

@Suite("Shared components")
@MainActor
struct SharedComponentTests {
    // Instantiating the new components proves they compile and build a view tree —
    // the unification layer the facelift depends on.
    @Test func componentsInstantiate() {
        _ = SectionHeader("Title", subtitle: "sub", symbol: "bolt", accent: IFMTheme.green)
        _ = SectionCard("Title", subtitle: "sub", symbol: "bolt", accent: IFMTheme.green) { Text("body") }
        _ = StatTile(value: "$1.00", label: "spent", symbol: "dollarsign.circle", accent: IFMTheme.green, trend: [1, 2, 3])
        _ = StatRow(title: "Missions", value: "3", accent: IFMTheme.blue)
        _ = StatusRow(title: "Firecrawl", isGood: true)
        _ = ToggleRow("On", subtitle: "desc", isOn: .constant(true))
    }
}

@Suite("Display terms")
struct DisplayTermTests {
    @Test func acronymsAndCasingReadNaturally() {
        #expect(ifmDisplayTerm("nft projects") == "NFT Projects")
        #expect(ifmDisplayTerm("hr performance surveillance") == "HR Performance Surveillance")
        #expect(ifmDisplayTerm("ambient memory") == "Ambient Memory")
        #expect(ifmDisplayTerm("ios") == "iOS")
        #expect(ifmDisplayTerm("github") == "GitHub")
        #expect(ifmDisplayTerm("crypto") == "Crypto")
    }
}

@Suite("Toast tone")
struct ToastToneTests {
    @Test func classifiesAppAuthoredNotices() {
        // Successes
        #expect(ToastTone.classify("Build plan created for Meeting memory.") == .success)
        #expect(ToastTone.classify("Critique queued for Ripening workflow.") == .success)
        #expect(ToastTone.classify("Imported whiteboard.webp, but local text extraction did not find readable text.") == .success)
        #expect(ToastTone.classify("New connector token generated. Re-paste it into the Chrome extension.") == .success)
        #expect(ToastTone.classify("Recorded outcome for Ambient memory: Shipped.") == .success)

        // Warnings (soft notices, not failures)
        #expect(ToastTone.classify("Already captured: Meeting memory.") == .warning)
        #expect(ToastTone.classify("Build plan already exists for Meeting memory.") == .warning)
        #expect(ToastTone.classify("Critique needs approval before cloud use.") == .warning)
        #expect(ToastTone.classify("3 job(s) need approval.") == .warning)
        #expect(ToastTone.classify("Add a Gemini API key in Settings first.") == .warning)

        // Info
        #expect(ToastTone.classify("No pending notifications.") == .info)
        #expect(ToastTone.classify("Nothing is ready to build yet. Capture an idea first.") == .info)
        #expect(ToastTone.classify("No ideas to ferment yet. Capture a seed in the Inbox first.") == .info)

        // Result confirmations
        #expect(ToastTone.classify("Local pass complete — scored 3 ideas. Ripe ones move to Ready.") == .success)
        #expect(ToastTone.classify("Queued 5 cloud jobs. Track them in the Cost Center.") == .success)

        // Instant inline AI: a finished cloud run reads as success; every local
        // fallback reads as a soft warning, never a red error.
        #expect(ToastTone.classify("Critique ready for Ripening workflow via Claude. It's on the idea's card and in Patterns.") == .success)
        #expect(ToastTone.classify("Ran a local critique for Ripening workflow — no cloud key yet. Add a key in Settings for a sharper one.") == .warning)
        #expect(ToastTone.classify("Ripening workflow is marked never-send, so it stayed local. Lift the privacy block to use the cloud.") == .warning)
        #expect(ToastTone.classify("Spend cap reached — ran a local critique for X instead. Raise the cap in Settings to keep using the cloud.") == .warning)
        #expect(ToastTone.classify("Cloud critique didn't land (timed out) — ran a local critique for X instead.") == .warning)
    }

    @Test func unknownMessagesDefaultToError() {
        #expect(ToastTone.classify("The database could not be opened.") == .error)
        #expect(ToastTone.classify("Something went wrong unexpectedly.") == .error)
        #expect(ToastTone.classify("This source has no file or URL to open.") == .error)
    }

    @Test func onlyErrorsPersistUntilDismissed() {
        #expect(ToastTone.error.autoDismiss == false)
        #expect(ToastTone.success.autoDismiss)
        #expect(ToastTone.warning.autoDismiss)
        #expect(ToastTone.info.autoDismiss)
    }
}
