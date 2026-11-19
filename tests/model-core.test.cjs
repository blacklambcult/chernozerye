const { test } = require("node:test");
const assert = require("node:assert/strict");
const model = require("../site/model/model-core.js");

test("create and serialize portable metric model", () => {
  const part = model.makePart("box", {id:"box-one", name:"Деталь", position:[1,2,-3], rotation:[0,45,0],scale:[1.5,2,0.2],color:"#ABCDEF"});
  const project = model.makeProject("Тест", [part]);
  assert.equal(project.format, "chernozerye.modellab");
  assert.equal(project.version, 1);
  assert.equal(project.units, "meters");
  assert.equal(project.parts[0].color, "#abcdef");
  assert.deepEqual(model.normalizeProject(JSON.parse(JSON.stringify(project))), project);
});

test("all five geometry types are supported and template objects stay independent", () => {
  const all = model.PRIMITIVES.map((type) => model.makePart(type));
  assert.equal(all.length, 5);
  assert.equal(new Set(all.map((p) => p.id)).size, 5);
  for (const preset of ["crate", "lantern", "marker"]) {
    const p = model.preset(preset);
    assert.ok(p.parts.length >= 3);
    assert.deepEqual(model.normalizeProject(p), p);
  }
  const a = model.preset("crate"), b = model.preset("crate");
  a.parts[0].position[0] += 3;
  assert.notEqual(a.parts[0].position[0], b.parts[0].position[0]);
});

test("duplicate creates unique independent part with safe offset", () => {
  const original = model.makePart("sphere");
  const copy = model.clonePart(original);
  assert.notEqual(copy.id, original.id);
  assert.deepEqual(copy.position, [original.position[0]+0.25, original.position[1], original.position[2]]);
  copy.scale[0] = 4;
  assert.equal(original.scale[0], 1);
});

test("reject unknown files, degenerate scales, oversized and duplicate IDs", () => {
  const part = model.makePart("box", {id:"p1"});
  const valid = model.makeProject("Good", [part]);
  assert.throws(() => model.normalizeProject({type:"FeatureCollection",features:[]}));
  assert.throws(() => model.makeProject("dup", [part,part]), /ID/);
  assert.throws(() => model.makePart("knife"), /Неизвестный/);
  assert.throws(() => model.makePart("box", {scale:[1,0,1]}), /Масштаб/);
  assert.throws(() => model.makePart("box", {position:[1,Infinity,0]}), /Позиция/);
  assert.throws(() => model.makePart("box", {color:"red"}), /Цвет/);
  assert.throws(() => model.makePart("box", {rotation:[0,0,999]}), /Поворот/);
  assert.throws(() => model.normalizeProject({...valid, units:"centimeters"}), /Model Lab/);
  assert.throws(() => model.normalizeProject({...valid, parts:Array.from({length:129}, (_,i)=>({...part,id:"p"+i}))}), /лимит/);
});
