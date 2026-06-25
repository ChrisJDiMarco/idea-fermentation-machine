const els = {
  disconnected: document.getElementById("disconnected"),
  pairLink: document.getElementById("pair-link"),
  openOptions: document.getElementById("open-options"),
  favicon: document.getElementById("favicon"),
  title: document.getElementById("title"),
  host: document.getElementById("host"),
  kindChip: document.getElementById("kind-chip"),
  note: document.getElementById("note"),
  tags: document.getElementById("tags"),
  saveAs: document.getElementById("save-as"),
  neverSend: document.getElementById("never-send"),
  save: document.getElementById("save"),
  captureView: document.getElementById("capture-view"),
  resultView: document.getElementById("result-view"),
  resultMessage: document.getElementById("result-message"),
  resultTags: document.getElementById("result-tags"),
  resultLinked: document.getElementById("result-linked"),
  resultIcon: document.getElementById("result-icon"),
  done: document.getElementById("done"),
  error: document.getElementById("error")
};

let payload = null;
let saveMode = "source";

function showError(message) {
  els.error.textContent = message;
  els.error.classList.remove("hidden");
}

function hostFromUrl(url) {
  try { return new URL(url).hostname.replace(/^www\./, ""); } catch (_) { return ""; }
}

function send(message) {
  return new Promise((resolve) => chrome.runtime.sendMessage(message, resolve));
}

async function prepare() {
  const response = await send({ type: "prepare" });
  if (!response || !response.ok) {
    showError((response && response.error) || "Could not read the page.");
    return;
  }
  if (!response.connected) {
    els.disconnected.classList.remove("hidden");
  }
  payload = response.payload;
  if (!payload) {
    els.title.textContent = "No page to save";
    els.save.disabled = true;
    return;
  }
  els.title.textContent = payload.title || payload.url;
  els.host.textContent = hostFromUrl(payload.url);
  if (payload.faviconURL) {
    els.favicon.src = payload.faviconURL;
    els.favicon.onerror = () => { els.favicon.style.visibility = "hidden"; };
  } else {
    els.favicon.style.visibility = "hidden";
  }
  if (payload.kindHint && payload.kindHint !== "page") {
    els.kindChip.textContent = payload.kindHint;
    els.kindChip.classList.remove("hidden");
  }
}

function renderResult(result) {
  els.captureView.classList.add("hidden");
  els.resultView.classList.remove("hidden");
  els.resultIcon.textContent = result.deduped ? "↺" : "✓";
  els.resultMessage.textContent = result.message || (result.deduped ? "Already saved" : "Saved");

  els.resultTags.innerHTML = "";
  (result.tags || []).slice(0, 6).forEach((tag) => {
    const chip = document.createElement("span");
    chip.className = "chip";
    chip.textContent = tag;
    els.resultTags.appendChild(chip);
  });

  els.resultLinked.innerHTML = "";
  if ((result.linkedIdeas || []).length) {
    const heading = document.createElement("div");
    heading.textContent = "Linked to your ideas:";
    els.resultLinked.appendChild(heading);
    result.linkedIdeas.slice(0, 5).forEach((title) => {
      const item = document.createElement("div");
      item.className = "linked-item";
      item.textContent = title;
      els.resultLinked.appendChild(item);
    });
  }
}

async function save() {
  if (!payload) return;
  els.save.disabled = true;
  els.save.textContent = "Saving…";
  const tags = els.tags.value.split(",").map((t) => t.trim()).filter(Boolean);
  const outgoing = {
    ...payload,
    note: els.note.value.trim() || null,
    tags: tags.length ? tags : null,
    neverSendToCloud: els.neverSend.checked,
    saveAs: saveMode
  };
  const response = await send({ type: "save", payload: outgoing });
  if (!response || !response.ok) {
    els.save.disabled = false;
    els.save.textContent = "Save to App";
    showError((response && response.error) || "Save failed.");
    return;
  }
  renderResult(response.result);
}

els.saveAs.addEventListener("click", (event) => {
  const button = event.target.closest("[data-mode]");
  if (!button) return;
  saveMode = button.dataset.mode;
  els.saveAs.querySelectorAll(".seg").forEach((b) => b.classList.toggle("active", b === button));
});

els.save.addEventListener("click", save);
els.done.addEventListener("click", () => window.close());
els.openOptions.addEventListener("click", () => chrome.runtime.openOptionsPage());
els.pairLink.addEventListener("click", (e) => { e.preventDefault(); chrome.runtime.openOptionsPage(); });

prepare();
