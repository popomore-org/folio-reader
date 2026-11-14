import mermaid from "mermaid";
import { View, parse } from "vega";
import { compile } from "vega-lite";
import { expressionInterpreter } from "vega-interpreter";
import { chartSpec, mermaidSource } from "./spec.js";

const article = document.querySelector("article");
const dark = () => document.documentElement.dataset.colorScheme === "dark";
const original = [...article.querySelectorAll("pre > code.language-mermaid, pre > code.language-vega-lite")]
  .map((code) => ({ pre: code.parentElement, source: code.textContent, mermaid: code.classList.contains("language-mermaid") }));
let draw = Promise.resolve();
let generation = 0;
const views = new Map();

async function diagrams(current) {
  mermaid.initialize({
    startOnLoad: false, securityLevel: "strict", suppressErrorRendering: true,
    theme: dark() ? "dark" : "neutral", maxTextSize: 64_000, maxEdges: 250,
    flowchart: { htmlLabels: false },
  });
  for (const [index, chart] of original.entries()) {
    if (current !== generation) return;
    const old = document.getElementById(`figure-${index}`);
    if (old) old.remove();
    views.get(index)?.finalize();
    views.delete(index);
    const figure = document.createElement("figure");
    figure.className = "diagram";
    figure.id = `figure-${index}`;
    chart.pre.before(figure);
    chart.pre.hidden = true;
    try {
      if (chart.mermaid) {
        const { svg } = await mermaid.render(`diagram-${current}-${index}`, mermaidSource(chart.source));
        figure.innerHTML = svg;
      } else {
        const spec = chartSpec(chart.source);
        const style = getComputedStyle(article);
        const ink = style.color;
        const line = style.getPropertyValue("--line").trim();
        const config = {
          background: "transparent",
          axis: { labelColor: ink, titleColor: ink, gridColor: line, domainColor: line, tickColor: line },
          title: { color: ink },
          legend: { labelColor: ink, titleColor: ink },
          header: { labelColor: ink, titleColor: ink },
          view: { stroke: line },
        };
        const runtime = parse(compile(spec, { config }).spec, null, { ast: true });
        const loader = {
          async load() { throw new Error("External chart data is disabled."); },
          async sanitize() { throw new Error("External chart resources are disabled."); },
        };
        const view = new View(runtime, { expr: expressionInterpreter, container: figure, renderer: "svg", loader, hover: true });
        views.set(index, view);
        await view.runAsync();
      }
    } catch (error) {
      figure.replaceChildren();
      figure.classList.add("diagram-error");
      figure.textContent = error instanceof Error ? error.message.split("\n")[0] : "The chart could not be rendered.";
      chart.pre.hidden = false;
    }
  }
}

function redraw() {
  const current = ++generation;
  draw = draw.then(() => diagrams(current));
}

window.addEventListener("folio-color-scheme", redraw);
redraw();
