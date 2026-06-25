const hostEl = document.getElementById("host");
const portEl = document.getElementById("port");
const tokenEl = document.getElementById("token");
const statusEl = document.getElementById("status");

function setStatus(message, ok) {
  statusEl.textContent = message;
  statusEl.classList.remove("hidden", "ok", "bad");
  statusEl.classList.add(ok ? "ok" : "bad");
}

function readForm() {
  return {
    host: hostEl.value.trim() || "127.0.0.1",
    port: Number(portEl.value) || 51720,
    token: tokenEl.value.trim()
  };
}

async function load() {
  const stored = await chrome.storage.local.get(["host", "port", "token"]);
  if (stored.host) hostEl.value = stored.host;
  if (stored.port) portEl.value = stored.port;
  if (stored.token) tokenEl.value = stored.token;
}

async function test() {
  const config = readForm();
  setStatus("Testing…", true);
  try {
    const response = await fetch(`http://${config.host}:${config.port}/health`, { method: "GET" });
    if (!response.ok) {
      setStatus(`App responded with HTTP ${response.status}.`, false);
      return false;
    }
    const body = await response.json();
    if (body && body.name === "IdeaFermentationMachine") {
      setStatus(`Connected to Idea Fermentation Machine v${body.version || "?"}.`, true);
      return true;
    }
    setStatus("Something is listening, but it isn't the app. Check the port.", false);
    return false;
  } catch (error) {
    setStatus("Can't reach the app. Is it running, and is the connector enabled in Settings?", false);
    return false;
  }
}

async function save() {
  const config = readForm();
  if (!config.token) {
    setStatus("Paste the pairing token from the app's Settings → Browser Connector.", false);
    return;
  }
  await chrome.storage.local.set(config);
  const ok = await test();
  if (ok) setStatus("Saved and connected. You're ready to capture.", true);
}

document.getElementById("test").addEventListener("click", test);
document.getElementById("save").addEventListener("click", save);
load();
