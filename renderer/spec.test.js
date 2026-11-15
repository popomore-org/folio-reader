import test from "node:test";
import assert from "node:assert/strict";
import { chartSpec, mermaidSource } from "./spec.js";

test("allows inline charts and blocks external dataset and navigation fields", () => {
  const source = JSON.stringify({mark: "bar", data: {values: [{name: "a", value: 1}]}});
  assert.equal(chartSpec(source).mark, "bar");
  for (const spec of ['{"data":{"url":"https://example.com"}}', '{"encoding":{"href":{"field":"link"}}}', '{"mark":"image"}']) {
    assert.throws(() => chartSpec(spec));
  }
});

test("rejects Mermaid configuration overrides", () => {
  assert.equal(mermaidSource("flowchart LR\n A --> B"), "flowchart LR\n A --> B");
  assert.throws(() => mermaidSource("%%{init: {}}%%\nflowchart LR"));
  assert.throws(() => mermaidSource("---\nconfig:\n---\nflowchart LR"));
});
