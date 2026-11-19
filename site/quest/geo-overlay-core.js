/* Shared map layer adapter for Quest Lab. No new copy of the user's Geo Lab data. */
(function(root, factory) {
  const value = factory();
  if (typeof module === "object" && module.exports) module.exports = value;
  root.ChernoQuestGeo = value;
})(typeof globalThis !== "undefined" ? globalThis : this, function() {
  "use strict";
  const STORAGE_KEY = "chernozerye_manual_geojson_v2";
  const SOURCES = Object.freeze([
    { id:"overture", file:"overture.geojson", title:"Здания Overture", color:"#ee9973" },
    { id:"roads", file:"roads.geojson", title:"Дороги OSM", color:"#e7b467" },
    { id:"vegetation", file:"vegetation.geojson", title:"Лес и растительность OSM", color:"#6abf88" },
    { id:"water", file:"water.geojson", title:"Вода OSM", color:"#60b9dd" }
  ]);
  const MANUAL_STYLES = Object.freeze({
    road: { color:"#ffca7f", weight:4, opacity:0.96 },
    path: { color:"#f3dd99", weight:2.5, dashArray:"7,5" },
    water: { color:"#63d1f5", weight:2.3, fillOpacity:0.38 },
    forest: { color:"#67d69b", weight:2.3, fillOpacity:0.28 },
    plot: { color:"#d3b2ff", weight:1.9, dashArray:"5,4", fillOpacity:0.08 },
    object: { color:"#d2d5ce", weight:2.1, fillOpacity:0.2 },
    house: { color:"#ff9868", weight:2.4, fillOpacity:0.37 },
    shed: { color:"#e4b583", weight:2.2, fillOpacity:0.36 },
    sauna: { color:"#f47b8a", weight:2.2, fillOpacity:0.32 },
    car: { color:"#8ec7fa", weight:2.2, fillOpacity:0.43 }
  });
  function readManual(raw, geoCore) {
    if (raw === null || raw === "") return [];
    if (typeof raw !== "string") throw new Error("Geo Lab storage value is not a string");
    if (!geoCore || typeof geoCore.importCollection !== "function")
      throw new Error("Geo Lab validation module not loaded");
    return geoCore.importCollection(JSON.parse(raw));
  }
  function sourceCounts(data) {
    if (!data || data.type !== "FeatureCollection" || !Array.isArray(data.features))
      throw new Error("Incorrect GeoJSON FeatureCollection");
    return data.features.length;
  }
  function manualStyle(category) {
    return { color:"#afbcb5", weight:1.9, opacity:0.94, fillOpacity:0.2,
      ...(MANUAL_STYLES[category] || {}) };
  }
  function sourceStyle(id) {
    const colors = {
      overture: { color:"#d18a69", weight:1.15, fillColor:"#c28563", fillOpacity:0.13, opacity:0.83 },
      roads: { color:"#d3b17b", weight:2.15, opacity:0.82 },
      vegetation: { color:"#69b889", fillColor:"#5eb47b", fillOpacity:0.16, weight:1.4, opacity:0.8 },
      water: { color:"#59b8d7", fillColor:"#4c9cbf", fillOpacity:0.3, weight:1.65, opacity:0.88 }
    };
    if (!Object.hasOwn(colors, id)) throw new Error("Unknown map data source: "+id);
    return {...colors[id]};
  }
  return Object.freeze({ STORAGE_KEY, SOURCES, MANUAL_STYLES,
    readManual, sourceCounts, sourceStyle, manualStyle });
});
