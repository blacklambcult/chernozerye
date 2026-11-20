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

test("collect steps author full note text and preserve it in old-schema Quest JSON",()=>{
  const note=core.createStep("collect","note-cordon");
  note.document={title:"Старая записка",body:"Строка первая\nСтрока вторая"};
  const q=core.createQuest("side","notes-demo");
  q.steps=[note];
  const project=core.makeProject([q]);
  const restored=core.normalizeProject(JSON.parse(JSON.stringify(project)));
  assert.equal(restored.quests[0].steps[0].document.title,"Старая записка");
  assert.equal(restored.quests[0].steps[0].document.body,"Строка первая\nСтрока вторая");
  const legacy=core.normalizeStep({...note,document:undefined});
  assert.equal(legacy.document,null);
  assert.throws(()=>core.normalizeStep({...note,document:{title:"X",body:"a".repeat(4001)}}),/длиннее/);
  assert.equal(core.normalizeStep({...note,type:"reach",document:note.document}).document,null);
});


test("independent world notes and items round-trip alongside legacy Quest Lab v1 projects",()=>{
  const old=core.makeProject();
  assert.deepEqual(old.worldItems,[]);
  const note=core.createWorldItem("note","world-letter");
  note.title="Письмо на дороге";
  note.body="Содержимое записки\nВторая строка.";
  note.target={lon:55.85485,lat:54.67368};
  note.objectId="survey-house-123";
  const item=core.createWorldItem("item","world-key");
  item.title="Ключ";
  item.body="Старый ключ";
  item.target={lon:55.8549,lat:54.6737};
  old.worldItems=[note,item];
  const normalized=core.normalizeProject(old);
  const restored=core.normalizeProject(JSON.parse(JSON.stringify(normalized)));
  assert.deepEqual(restored.worldItems,normalized.worldItems);
  assert.equal(restored.worldItems[0].body,"Содержимое записки\nВторая строка.");
  assert.equal(restored.worldItems[0].objectId,"survey-house-123");
  assert.deepEqual(core.normalizeProject({...old,worldItems:undefined}).worldItems,[]);
});
test("world item drafts are valid, duplicate IDs and malformed content are rejected",()=>{
  const incomplete=core.createWorldItem("note","world-draft");
  assert.equal(core.normalizeWorldItem(incomplete).target,null);
  const duplicate=core.makeProject();
  duplicate.worldItems=[incomplete,incomplete];
  assert.throws(()=>core.normalizeProject(duplicate),/Повторяющийся ID находки/);
  assert.throws(()=>core.normalizeWorldItem({...incomplete,type:"trap"}),/тип мировой находки/);
  assert.throws(()=>core.normalizeWorldItem({...incomplete,target:{lon:999,lat:50}}),/WGS84/);
  assert.throws(()=>core.normalizeWorldItem({...incomplete,body:"x".repeat(4001)}),/длиннее/);
  assert.throws(()=>core.normalizeProject({...duplicate,worldItems:Array.from({length:151},()=>incomplete)}),/Слишком много/);
});

test("catalog note links and character records survive project roundtrip", () => {
  const quest = core.createQuest("main", "quest-link");
  const step = core.createStep("collect", "find-letter");
  const note = core.createWorldItem("note", "letter");
  step.noteId = note.id;
  quest.steps.push(step);
  const input = { ...core.makeProject(), quests: [quest], worldItems: [note],
    characters: [{ id: "character-1", name: "Сторож", description: "Живёт у станции." }] };
  const result = core.normalizeProject(input);
  assert.equal(result.quests[0].steps[0].noteId, note.id);
  assert.deepEqual(result.characters, input.characters);
  assert.throws(() => core.normalizeProject({ ...input, worldItems: [] }), /отсутствует/);
});
