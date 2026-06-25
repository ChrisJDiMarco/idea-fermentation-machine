# Idea Fermentation Machine

Native macOS 14+ local-first agentic app for capturing ideas, fermenting them with low-cost AI loops, and turning ready ideas into build briefs.

## Build

```bash
swift test
Scripts/build_app.sh
open dist/IdeaFermentationMachine.app
```

## Production Status

The app starts with an empty local database. There is no bundled demo data.

Implemented user-facing surfaces:

- Inbox capture
- Source import and URL/text capture
- Local fermentation pass
- Cloud job queue and approvals
- Patterns (on-device semantic connections via Apple's NLEmbedding; novelty scored
  as distance from your existing corpus — "unlike anything you've thought before")
- Autonomy: scout missions that route new signals onto existing ideas or, with a
  cloud key, synthesize an original idea from them; a self-tuning Scout Focus that
  steers what the scout hunts for toward the themes you actually build and away from
  ones you abandon; an editable taste profile; and a self-tuning Learned Taste model
  that adapts local scoring to what you mark Ready, build, or archive
- Settings and Keychain-backed provider keys
- Cost Center
- Privacy Center
- Archive (a real lessons ledger: record a build outcome — shipped / built /
  abandoned / flopped + a note — and it teaches your taste model harder than a
  mark-ready and feeds the cloud-synthesis memory)
- Browser Connector (Chrome extension → loopback capture; see `ChromeExtension/`)

## Browser Connector

A loopback HTTP server (127.0.0.1, token-paired, token stored in Keychain) lets
the bundled Chrome extension (`ChromeExtension/`) save any page directly into
Sources — auto-classified, tagged, and linked to related ideas. Pair it from
**Settings → Browser Connector**. The app keeps running with its window closed so
captures always work (quit with ⌘Q). Regenerate the extension icons with
`swift Scripts/make_extension_icons.swift`.

## Local Data

The app stores SQLite data and attachments under:

```text
~/Library/Application Support/IdeaFermentationMachine/
```

API keys are BYOK and stored in macOS Keychain under `com.chrisdimarco.idea-fermentation-machine`.
