# Idea Fermentation — Chrome Connector

Save any page you're on straight into the Idea Fermentation Machine. The app
auto-classifies it (Article, Repository, Video, Discussion, …), pulls clean
readable text, derives tags, and links it to your related ideas — instantly, and
fully local.

## How it works

The desktop app runs a tiny HTTP server bound to `127.0.0.1` (loopback only). The
extension POSTs the captured page to it, authenticated with a pairing token. The
token is the security boundary: a random web page cannot read it, web origins are
rejected outright, and the server only listens on the loopback interface. Nothing
leaves your Mac.

## Install (unpacked)

1. Open the **Idea Fermentation Machine** app.
2. In Chrome, go to `chrome://extensions`, enable **Developer mode** (top right).
3. Click **Load unpacked** and select this `ChromeExtension` folder.

## Pair (one time)

1. In the app: **Settings → Browser Connector** → **Copy Token**.
2. In Chrome: open the extension's **Options** (right-click the toolbar icon →
   Options, or the ⚙ in the popup).
3. Paste the token, confirm host `127.0.0.1` and port (default `51720`), click
   **Test connection**, then **Save**.

If the port shown in the app isn't `51720` (it falls back when the port is busy),
match it in Options.

## Use

- **Toolbar icon** → preview, add an optional note/tags, choose **Source** or
  **Idea**, toggle **Never send to cloud**, then **Save**.
- **Right-click** a page, selection, or link → **Save … to Idea Fermentation**.
- **Keyboard**: `⌘⇧S` (Mac) / `Ctrl+Shift+S` saves the current page.

Saves appear in the app's **Sources** within about a second, categorized and
linked. The app keeps running with its window closed so saving always works —
quit with `⌘Q` or Dock → Quit.

## Permissions

- `activeTab` + `scripting` — read the current page only when you invoke a save
  (no broad `<all_urls>` access).
- `http://127.0.0.1/*` — talk to the local app.
- `contextMenus`, `commands`, `storage`, `notifications` — menus, shortcut,
  saved connection settings, and save confirmations.

## Privacy & security

- Loopback-only server; the **pairing token** is the real access gate.
- Web-page origins (`http(s)://…`) are rejected even with a token, so a malicious
  site's `fetch` can't trigger a save.
- The token is stored in the macOS **Keychain** on the app side. Rotate it any
  time with **Regenerate** in the app, then re-paste here.
