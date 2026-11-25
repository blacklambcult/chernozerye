const { test } = require("node:test");
const assert = require("node:assert/strict");
const state = require("../site/studio/studio-state.js");

test("three existing editors retain their original browser-storage keys", () => {
  assert.deepEqual(state.KEYS, {
    geo:"chernozerye_manual_geojson_v2",
    quest:"chernozerye.questlab.v1",
    model:"chernozerye.modellab.v1",
    forge:"chernozerye.hellish-forge.v1"
  });
  assert.deepEqual(state.TOOLS, ["home", "geo", "quest", "model", "forge", "weapon", "arms", "buildings", "nature", "npc"]);
});

test("the studio routes only known sections and handles shareable hash links", () => {
  for (const p of state.TOOLS) assert.equal(state.toolId("#" + p), p);
  assert.equal(state.toolId("#MAP"), "home");
  assert.equal(state.toolId("#../../secret"), "home");
  assert.equal(state.toolId(""), "home");
});

test("read-only project summary preserves data and works with empty/invalid storage", () => {
  const docs = {
    [state.KEYS.geo]: JSON.stringify({type:"FeatureCollection", features:[{}, {}, {}]}),
    [state.KEYS.quest]: JSON.stringify({format:"chernozerye.questlab",version:1,quests:[{id:"x"}]}),
    [state.KEYS.model]: JSON.stringify({format:"chernozerye.modellab",version:1,parts:[{id:"a"},{id:"b"}]}),
    [state.KEYS.forge]: JSON.stringify({format:"chernozerye.hellish-forge",version:1,parts:[{id:"a"},{id:"b"},{id:"c"}]})
  };
  const storage = {getItem(key) { return docs[key] || null; }};
  assert.deepEqual(state.snapshot(storage), {geo:3,quest:1,model:2,forge:3});
  assert.equal(state.snapshot({getItem(){return null;}}).geo,0);
  const before = structuredClone(docs);
  state.snapshot(storage);
  assert.deepEqual(docs,before);
  docs[state.KEYS.model] = "<not-json>";
  assert.equal(state.snapshot(storage).model,null);
  assert.equal(state.snapshot(storage).quest,1);
});

test("storage API failure is displayed as unavailable without erasing other counters", () => {
  const s = state.snapshot({getItem(key) {if(key===state.KEYS.geo)throw Error("disabled");return null;}});
  assert.deepEqual(s, {geo:null,quest:0,model:0,forge:0});
});

test("iframe routes work at a project prefix, root and explicit index.html",()=>{
  for(const studio of ["https://example.test/chernozerye/studio/","https://example.test/studio/index.html"]){
    assert.equal(state.routeForUrl("../quest/?model=demo",studio),"quest");
    assert.equal(state.routeForUrl("../npc/index.html",studio),"npc");
    assert.equal(state.routeForUrl("../map",studio),"geo");
    assert.equal(state.routeForUrl("../studio/#home",studio),"home");
    assert.equal(state.routeForUrl("../",studio),null);
    assert.equal(state.routeForUrl("../quest/unknown.html",studio),null);
    assert.equal(state.routeForUrl("https://other.test/quest/",studio),null);
  }
});
test("keyboard mappings are identical in shell and editor frames",()=>{
  state.TOOLS.forEach((id,i)=>assert.equal(state.shortcut({altKey:true,code:"Digit"+i}),id));
  assert.equal(state.shortcut({altKey:true,ctrlKey:true,code:"Digit1"}),null);
  assert.equal(state.shortcut({altKey:true,shiftKey:true,code:"Digit1"}),null);
  assert.equal(state.shortcut({altKey:false,code:"Digit1"}),null);
});
