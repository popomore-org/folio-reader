window.folioAppearance = (scheme, size, width, serif, colors) => {
  const root = document.documentElement;
  const schemeChanged = root.dataset.colorScheme !== scheme;
  root.dataset.colorScheme = scheme;
  root.style.setProperty("--text-size", `${size}px`);
  root.style.setProperty("--reading-width", `${width}px`);
  for (const [name, value] of Object.entries(colors)) root.style.setProperty(name, value);
  root.dataset.serif = String(serif);
  if (schemeChanged) window.dispatchEvent(new Event("folio-color-scheme"));
};

window.folioHeading = (id) => document.getElementById(id)?.scrollIntoView({ block: "start" });

document.addEventListener("click", (event) => {
  const anchor = event.target.closest("a[href]");
  if (anchor?.getAttribute("href").startsWith("#")) {
    event.preventDefault();
    try {
      window.folioHeading(decodeURIComponent(anchor.getAttribute("href").slice(1)));
    } catch { /* Ignore malformed fragments. */ }
  }
});

let scrollFrame;
window.addEventListener("scroll", () => {
  if (scrollFrame !== undefined) return;
  scrollFrame = requestAnimationFrame(() => {
    scrollFrame = undefined;
    window.webkit?.messageHandlers.folioScroll.postMessage(window.scrollY);
  });
}, { passive: true });
