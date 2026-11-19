const { test } = require("node:test");
const assert = require("node:assert/strict");
const layers = require("../site/quest/geo-overlay-core.js");
const geo = require("../site/map/editor-core.js");

test("Quest Lab reads exactly the same saved Geo Lab feature collection without modifying it", () => {
  const building = geo.makeFeature("house", { type:"Polygon", coordinates:[[
    [55.852,54.672],[55.8522,54.672],[55.8522,54.6722],[55.852,54.6722],[55.852,54.672]
  ]]});
  const forest = geo.makeFeature("forest", { type:"Polygon", coordinates:[[
    [55.853,54.672],[55.8532,54.672],[55.8532,54.6722],[55.853,54.6722],[55.853,54.672]
  ]]});
  const water = geo.makeFeature("water", { type:"Polygon", coordinates:[[
    [55.854,54.672],[55.8542,54.672],[55.8542,54.6722],[55.854,54.6722],[55.854,54.672]
  ]]});
  const doc = geo.collectionFromFeatures([building,forest,water]);
  const serialized = JSON.stringify(doc);
  const items = layers.readManual(serialized, geo);
  assert.deepEqual(items, geo.importCollection(doc));
  assert.equal(JSON.stringify(doc), serialized);
  assert.deepEqual(items.map(i=>i.properties.category),["house","forest","water"]);
  assert.equal(items[0].id, building.id);
});

test("styles distinguish houses, forests, lakes, roads and authored geometry", () => {
  assert.equal(layers.sourceStyle("overture").color, "#d18a69");
  assert.equal(layers.sourceStyle("vegetation").fillColor, "#5eb47b");
  assert.equal(layers.sourceStyle("water").fillColor, "#4c9cbf");
  assert.equal(layers.sourceStyle("roads").color, "#d3b17b");
  assert.equal(layers.manualStyle("house").color, "#ff9868");
  assert.equal(layers.manualStyle("forest").color, "#67d69b");
  assert.equal(layers.manualStyle("water").color, "#63d1f5");
  assert.equal(layers.SOURCES.length, 4);
});

test("invalid or unrelated data cannot masquerade as editable map objects", () => {
  assert.deepEqual(layers.readManual(null,geo), []);
  assert.throws(()=>layers.readManual('{"type":"FeatureCollection","features":[{}]}',geo));
  assert.throws(()=>layers.readManual('{"format":"chernozerye.questlab"}',geo));
  assert.throws(()=>layers.readManual('not json',geo));
  assert.equal(layers.sourceCounts({type:"FeatureCollection",features:[{},{}]}),2);
  assert.throws(()=>layers.sourceCounts({type:"hello"}));
});
