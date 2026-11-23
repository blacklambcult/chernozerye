/* Shared Studio 0.1 state reader, intentionally read-only. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.ChernoStudioState = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const KEYS = Object.freeze({
    geo: "chernozerye_manual_geojson_v2",
    quest: "chernozerye.questlab.v1",
    model: "chernozerye.modellab.v1",
    forge: "chernozerye.hellish-forge.v1"
  });
  const TOOLS = Object.freeze(["home", "geo", "quest", "model", "forge", "weapon", "arms", "buildings", "nature"]);
  function toolId(hash) {
    const id = typeof hash === "string" ? hash.replace(/^#/, "").toLowerCase() : "";
    return TOOLS.includes(id) ? id : "home";
  }
  function countFor(key, raw) {
    if (!raw || typeof raw !== "string") return 0;
    let data;
    try { data = JSON.parse(raw); }
    catch { return null; }
    if (!data || typeof data !== "object") return null;
    if (key === "geo") return data.type === "FeatureCollection" && Array.isArray(data.features) ? data.features.length : null;
    if (key === "quest") return data.format === "chernozerye.questlab" && data.version === 1 &&
      Array.isArray(data.quests) ? data.quests.length : null;
    if (key === "model") return data.format === "chernozerye.modellab" && data.version === 1 &&
      Array.isArray(data.parts) ? data.parts.length : null;
    if (key === "forge") return data.format === "chernozerye.hellish-forge" && data.version === 1 &&
      Array.isArray(data.parts) ? data.parts.length : null;
    return null;
  }
  function snapshot(storage) {
    const result = {};
    for (const type of Object.keys(KEYS)) {
      try { result[type] = countFor(type, storage.getItem(KEYS[type])); }
      catch { result[type] = null; }
    }
    return result;
  }
  return Object.freeze({ KEYS, TOOLS, toolId, countFor, snapshot });
});
