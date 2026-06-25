// Service worker: the single place that talks to the local app. Reads the paired
// connection (host/port/token) from storage, extracts the active tab, and POSTs
// to the app's loopback capture endpoint.

const DEFAULTS = { host: "127.0.0.1", port: 51720, token: "" };

async function getConfig() {
  const stored = await chrome.storage.local.get(["host", "port", "token"]);
  return {
    host: stored.host || DEFAULTS.host,
    port: Number(stored.port) || DEFAULTS.port,
    token: stored.token || DEFAULTS.token
  };
}

function endpoint(config, path) {
  return `http://${config.host}:${config.port}${path}`;
}

async function ping(config) {
  try {
    const response = await fetch(endpoint(config, "/health"), { method: "GET" });
    if (!response.ok) return { ok: false, reason: `HTTP ${response.status}` };
    const body = await response.json();
    return { ok: body && body.name === "IdeaFermentationMachine", name: body && body.name };
  } catch (error) {
    return { ok: false, reason: String(error && error.message ? error.message : error) };
  }
}

async function extractActiveTab(tab) {
  // activeTab is granted on action click, context menu, and command — so scripting works here.
  const [injection] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    files: ["extractor.js"]
  });
  const base = (injection && injection.result) || {};
  return {
    url: base.url || tab.url || "",
    title: base.title || tab.title || "",
    selectionText: base.selectionText || "",
    pageText: base.pageText || "",
    excerpt: base.excerpt || "",
    siteName: base.siteName || "",
    author: base.author || null,
    publishedTime: base.publishedTime || null,
    faviconURL: base.faviconURL || tab.favIconUrl || null,
    kindHint: base.kindHint || "page"
  };
}

async function saveToApp(payload) {
  const config = await getConfig();
  if (!config.token) {
    throw new Error("Not paired. Open the extension options and paste the token from the app's Settings → Browser Connector.");
  }
  const response = await fetch(endpoint(config, "/capture"), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.token}`
    },
    body: JSON.stringify({ ...payload, capturedAt: Date.now() / 1000 })
  });
  const text = await response.text();
  if (!response.ok) {
    let message = `Save failed (HTTP ${response.status})`;
    if (response.status === 401) message = "Save rejected: the token doesn't match. Re-pair in options.";
    else if (text) message = text;
    throw new Error(message);
  }
  return JSON.parse(text);
}

function notify(title, message) {
  chrome.notifications.create({
    type: "basic",
    iconUrl: "icons/icon128.png",
    title,
    message: message || ""
  });
}

// One-shot save used by the context menu and keyboard command (no popup UI).
async function quickSave(tab, overrides) {
  try {
    const payload = { ...(await extractActiveTab(tab)), ...overrides };
    const result = await saveToApp(payload);
    notify(result.deduped ? "Already saved" : "Saved to Idea Fermentation", result.message);
  } catch (error) {
    notify("Couldn't save", error.message || String(error));
  }
}

// --- Context menus ---

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({ id: "ifm-save-page", title: "Save page to Idea Fermentation", contexts: ["page"] });
  chrome.contextMenus.create({ id: "ifm-save-selection", title: "Save selection to Idea Fermentation", contexts: ["selection"] });
  chrome.contextMenus.create({ id: "ifm-save-link", title: "Save link to Idea Fermentation", contexts: ["link"] });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (!tab) return;
  if (info.menuItemId === "ifm-save-selection") {
    quickSave(tab, { selectionText: info.selectionText || "" });
  } else if (info.menuItemId === "ifm-save-link") {
    quickSave(tab, { url: info.linkUrl || tab.url, kindHint: "page" });
  } else {
    quickSave(tab, {});
  }
});

// --- Keyboard command ---

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "save-page") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab) quickSave(tab, {});
});

// --- Popup messaging ---

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    try {
      if (message.type === "prepare") {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        const config = await getConfig();
        const status = await ping(config);
        const payload = tab ? await extractActiveTab(tab) : null;
        sendResponse({ ok: true, connected: status.ok, status, payload });
      } else if (message.type === "save") {
        const result = await saveToApp(message.payload);
        sendResponse({ ok: true, result });
      } else if (message.type === "ping") {
        sendResponse({ ok: true, status: await ping(await getConfig()) });
      } else {
        sendResponse({ ok: false, error: "Unknown message" });
      }
    } catch (error) {
      sendResponse({ ok: false, error: error.message || String(error) });
    }
  })();
  return true; // keep the channel open for the async response
});
