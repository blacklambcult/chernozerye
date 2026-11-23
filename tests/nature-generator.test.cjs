const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const read = file => fs.readFileSync(path.join(__dirname, "..", file), "utf8");

test("nature generator provides five categories and compiles without modules", () => {
  const page = read("site/nature-generator/index.html");
  for (const [, source] of page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)) new vm.Script(source);
  for (const type of ["tree", "bush", "rock", "water", "mystic"]) assert.ok(page.includes('data-cat="' + type + '"'));
  assert.match(page, /binary: true, animations: state\.cat === 'mystic' \? mysticClips/);
});

test("Studio routes nature from shared library to Quest Lab", () => {
  const page = read("site/nature-generator/index.html");
  assert.match(page, /await exportNature\(false\)/);
  assert.match(page, /await window\.ChernoObjectLibrary\.saveModel/);
  assert.match(page, /url\.searchParams\.set\('model', id\)/);
  assert.match(read("site/studio/index.html"), /data-target="nature"/);
  assert.match(read("site/studio/studio.js"), /Digit8:"nature"/);
});
