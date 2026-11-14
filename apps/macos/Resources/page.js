window.folioAppearance = (theme, size, width, serif) => {
  document.documentElement.dataset.theme = theme;
  document.documentElement.style.setProperty("--text-size", `${size}px`);
  document.documentElement.style.setProperty("--reading-width", `${width}px`);
  document.documentElement.dataset.serif = String(serif);
  window.dispatchEvent(new Event("folio-theme"));
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
