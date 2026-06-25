// Runs in the page context via chrome.scripting.executeScript({ files: ["extractor.js"] }).
// The trailing IIFE's return value becomes the injection result. Pure, dependency-free,
// and fully auditable — it only reads the DOM and never calls out anywhere.
(() => {
  const META_LIMIT = 400;
  const BODY_LIMIT = 40000;

  const meta = (key) => {
    const el = document.querySelector(
      `meta[property="${key}"], meta[name="${key}"], meta[itemprop="${key}"]`
    );
    const value = el && el.getAttribute("content");
    return value ? value.trim() : null;
  };

  const readableBody = () => {
    const selectors = ["article", "main", '[role="main"]', "#content", ".post", ".article", ".entry-content"];
    let root = null;
    for (const selector of selectors) {
      const el = document.querySelector(selector);
      if (el && (el.innerText || "").trim().length > 200) { root = el; break; }
    }
    if (!root) root = document.body;
    const clone = root.cloneNode(true);
    clone
      .querySelectorAll("script,style,noscript,nav,aside,header,footer,form,iframe,svg,button")
      .forEach((node) => node.remove());
    const text = (clone.innerText || clone.textContent || "")
      .replace(/[ \t]{2,}/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
    return text.slice(0, BODY_LIMIT);
  };

  const selection = () => {
    try {
      return window.getSelection ? String(window.getSelection()).trim() : "";
    } catch (_) {
      return "";
    }
  };

  const favicon = () => {
    const link = document.querySelector('link[rel~="icon"], link[rel="shortcut icon"]');
    if (link && link.href) return link.href;
    return location.origin + "/favicon.ico";
  };

  const host = location.hostname.replace(/^www\./, "");
  const path = location.pathname.toLowerCase();
  const ogType = (meta("og:type") || "").toLowerCase();

  let kindHint = "page";
  if (path.endsWith(".pdf")) kindHint = "pdf";
  else if (/(^|\.)github\.|(^|\.)gitlab\.|(^|\.)bitbucket\./.test(host)) kindHint = "repo";
  else if (/youtube\.|youtu\.be|vimeo\./.test(host)) kindHint = "video";
  else if (/twitter\.|^x\.com$|(^|\.)reddit\.|news\.ycombinator\.|mastodon|bsky\.|threads\.net|(^|\.)linkedin\./.test(host)) kindHint = "social";
  else if (/notion\.|docs\.google\.|figma\./.test(host)) kindHint = "doc";
  else if (ogType === "article") kindHint = "article";

  return {
    url: location.href,
    title: (meta("og:title") || document.title || "").trim(),
    selectionText: selection(),
    pageText: readableBody(),
    excerpt: (meta("og:description") || meta("description") || "").slice(0, META_LIMIT),
    siteName: meta("og:site_name") || host,
    author: meta("article:author") || meta("author") || null,
    publishedTime: meta("article:published_time") || meta("date") || null,
    faviconURL: favicon(),
    kindHint
  };
})();
