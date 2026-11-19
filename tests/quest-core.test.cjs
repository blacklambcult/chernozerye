const test = require("node:test");
const assert = require("node:assert/strict");
const core = require("../site/quest/quest-core.js");

test("main/side quests and message/target steps round-trip in JSON", () => {
  const main = core.createQuest("main", "chapter-01");
  main.title = "Возвращение";
  main.description = "Исследовать дом";
  main.spawn = { lon: 55.852815, lat: 54.672897, bearing: 180 };
  const reach = core.createStep("reach", "reach-home");
  reach.target = { lon: 55.8528, lat: 54.6729 };
  reach.objectId = "survey-home";
  const message = core.createStep("message", "intro-line");
  message.title = "Вступление";
  message.text = "Чернозёрье встречает тишиной.";
  main.steps = [reach, message];
  const side = core.createQuest("side", "side-01");
  side.title = "Побочная история";
  const project = core.makeProject([main, side], main.id);
  assert.equal(project.quests.length, 2);
  assert.equal(project.coordinates, "WGS84");
  assert.deepEqual(core.normalizeProject(JSON.parse(JSON.stringify(project))), project);
  assert.equal(project.quests[0].steps[0].objectId, "survey-home");
});

test("new projects and quests support empty story sequences", () => {
  const empty = core.makeProject();
  assert.equal(empty.selectedId, null);
  assert.deepEqual(empty.quests, []);
  assert.equal(core.createQuest("main", "quest-123").steps.length, 0);
  assert.deepEqual(core.DEFAULT_SPAWN, { lon: 55.852815, lat: 54.672897, bearing: 0 });
});

test("step ordering is explicit and does not mutate original input", () => {
  const q = core.createQuest("main", "ordered");
  q.steps = [core.createStep("reach", "a"), core.createStep("interact", "b"), core.createStep("message", "c")];
  const moved = core.moveStep(q, 2, -1);
  assert.deepEqual(moved.steps.map(s => s.id), ["a", "c", "b"]);
  assert.deepEqual(q.steps.map(s => s.id), ["a", "b", "c"]);
  assert.deepEqual(core.moveStep(q, 0, -1).steps.map(s => s.id), ["a", "b", "c"]);
});

test("refuses malformed imports, colliding IDs, invalid locations, and rogue node types", () => {
  const q = core.createQuest("main", "dup");
  q.title = "A";
  assert.throws(() => core.normalizeProject({ type: "FeatureCollection", features: [] }));
  assert.throws(() => core.makeProject([q, q]), /ID квеста/);
  assert.throws(() => core.normalizeQuest({ ...q, type: "unknown" }), /Тип квеста/);
  assert.throws(() => core.normalizeQuest({ ...q, spawn: { lon: 999, lat: 54, bearing: 0 } }), /WGS84/);
  assert.throws(() => core.normalizeQuest({ ...q, spawn: { lon: 55, lat: 54, bearing: 360 } }), /Курс/);
  assert.throws(() => core.normalizeQuest({ ...q, steps: [{ ...core.createStep("reach", "x"), type: "script" }] }), /тип задачи/);
  assert.throws(() => core.normalizeQuest({ ...q, steps: [core.createStep("reach", "x"), core.createStep("message", "x")] }), /ID задачи/);
  assert.throws(() => core.normalizeQuest({ ...q, title: "x".repeat(141) }), /длиннее/);
});
