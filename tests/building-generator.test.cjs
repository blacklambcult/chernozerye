const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const read = file => fs.readFileSync(path.join(__dirname, "..", file), "utf8");

test("building generator stays a standalone UMD editor with four builders", () => {
  const page = read("site/building-generator/index.html");
  const scripts = [...page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];
  assert.ok(scripts.length >= 4);
  for (const [, source] of scripts) new vm.Script(source);
  assert.doesNotMatch(page, /type=["'](?:module|importmap)/);
  for (const type of ["Izba", "Banya", "Saray", "Zabor"])
    assert.match(page, new RegExp("function build" + type + "\\("));
});

test("Studio routes saved models into the Quest Lab placement picker", () => {
  const page = read("site/building-generator/index.html");
  assert.match(page, /await exportBuilding\(false\)/);
  assert.match(page, /await window\.ChernoObjectLibrary\.saveModel/);
  assert.match(page, /url\.searchParams\.set\('model', id\)/);
  assert.match(read("site/studio/index.html"), /data-target="buildings"/);
  assert.match(read("site/studio/studio.js"), /editorUrl\.searchParams\.has\("model"\)/);
  assert.match(read("site/quest/quest.js"), /const selected = requestedModel \|\| picker\.value/);
});
