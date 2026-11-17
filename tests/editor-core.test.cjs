const test = require("node:test");
const assert = require("node:assert/strict");
const core = require("../site/map/editor-core.js");

const A = [55.851, 54.673];
const B = [55.8513, 54.673];
const C = [55.8513, 54.6733];

test("manual road exports real WGS84 coordinates and returns valid lengths", () => {
  const feature = core.makeFeature("line-1", "road", { type: "LineString", coordinates: [A, B] }, "Дачная");
  assert.equal(feature.properties.category, "road");
  assert.equal(feature.geometry.coordinates.length, 2);
  assert.ok(core.measure(feature).length_m > 10);
  const again = core.importCollection(core.collectionFromFeatures([feature]));
  assert.deepEqual(again, [feature]);
});
test("plot, water, house polygons close and measure correctly", () => {
  for (const category of ["plot", "water", "forest", "house", "shed", "sauna", "object", "car"]) {
    const feature = core.makeFeature("one-" + category, category, {
      type: "Polygon", coordinates: [[A, B, C]]
    });
    assert.deepEqual(feature.geometry.coordinates[0][0], feature.geometry.coordinates[0][3]);
    assert.ok(core.measure(feature).area_m2 > 10);
    assert.deepEqual(core.importCollection(core.collectionFromFeatures([feature]))[0], feature);
  }
});
test("a car may also be a single marker point", () => {
  const feature = core.makeFeature("car-1", "car", { type: "Point", coordinates: A }, "Машина");
  assert.deepEqual(feature.geometry.coordinates, A);
  assert.equal(core.measure(feature).area_m2, 0);
});
test("reject unknown category, malformed geometry and foreign coordinates", () => {
  assert.equal(core.normalizeGeometry({ type: "LineString", coordinates: [A, B] }, "house"), null);
  assert.equal(core.normalizeGeometry({ type: "Point", coordinates: [A] }, "car"), null);
  assert.equal(core.normalizeGeometry({ type: "Point", coordinates: [15, 10] }, "car"), null);
  assert.equal(core.normalizeGeometry({ type: "Polygon", coordinates: [[A, B]] }, "plot"), null);
  assert.equal(core.normalizeFeature({ type: "Feature", properties: { category: "unknown", id: "bad" }, geometry: { type: "Point", coordinates: A } }), null);
});
test("reject damaged imports and duplicate object IDs", () => {
  assert.throws(() => core.importCollection({ type: "FeatureCollection", features: [{ type: "Feature" }] }));
  const one = core.makeFeature("duplicate", "path", { type: "LineString", coordinates: [A, B] });
  assert.throws(() => core.importCollection({ type: "FeatureCollection", features: [one, one] }), /Повторяющийся/);
});
