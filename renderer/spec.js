const allowedMarks = new Set([
  "arc", "area", "bar", "boxplot", "circle", "errorband", "errorbar",
  "line", "point", "rect", "rule", "square", "text", "tick", "trail",
]);

// Diagrams run from a bundled renderer. Diagram-level configuration would
// otherwise let an author override site-wide rendering preferences.
export function mermaidSource(source) {
  if (source.length > 64_000 || /^\s*---\s*\n/.test(source) || /%%\s*\{/.test(source)) {
    throw new Error("Remove Mermaid configuration headers and directives.");
  }
  return source;
}

export function chartSpec(source) {
  if (source.length > 256_000) throw new Error("The chart specification is too large.");
  const spec = JSON.parse(source);
  if (!spec || typeof spec !== "object" || Array.isArray(spec)) {
    throw new Error("Expected a Vega-Lite JSON object.");
  }
  function visit(value) {
    if (!value || typeof value !== "object") return;
    for (const [key, child] of Object.entries(value)) {
      if (["__proto__", "prototype", "constructor", "url", "href"].includes(key)) {
        throw new Error("Charts require inline data and local labels.");
      }
      if (key === "mark") {
        const type = typeof child === "string" ? child : child?.type;
        if (!allowedMarks.has(type)) throw new Error("Unsupported Vega-Lite mark.");
      }
      if (key !== "$schema") visit(child);
    }
  }
  visit(spec);
  return spec;
}
