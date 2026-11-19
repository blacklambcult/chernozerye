/* MODEL LAB 0.1 — stable portable scene schema, no three.js dependency. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.ChernoModelCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const FORMAT = "chernozerye.modellab";
  const VERSION = 1;
  const PRIMITIVES = Object.freeze(["box", "cylinder", "sphere", "cone", "plane"]);
  const MAX_PARTS = 128;
  const PALETTE = Object.freeze(["#977256","#413a33","#a79980","#53615b","#c4a778","#734f42","#757b80","#b67644","#1d292d","#d7b98a"]);
  let localCounter = 0;

  function asString(input, max, label) {
    if (typeof input !== "string" || input.length > max) throw new Error(label + ": неверная строка.");
    return input.trim();
  }
  function number(input, low, high, label) {
    if (typeof input !== "number" || !Number.isFinite(input) || input < low || input > high)
      throw new Error(label + " должен быть в диапазоне " + low + "…" + high + ".");
    return Math.round(input * 1000000) / 1000000;
  }
  function vector(input, low, high, label) {
    if (!Array.isArray(input) || input.length !== 3) throw new Error(label + ": нужны три числа.");
    return input.map((n) => number(n, low, high, label));
  }
  function ident(raw) {
    const id = asString(raw, 96, "ID");
    if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(id)) throw new Error("Некорректный ID детали.");
    return id;
  }
  function makeId() {
    localCounter += 1;
    const rnd = typeof crypto !== "undefined" && crypto.randomUUID ?
      crypto.randomUUID().slice(0, 8) : Math.random().toString(36).slice(2, 10);
    return "part-" + rnd + "-" + localCounter.toString(36);
  }
  function makePart(primitive = "box", overrides = {}) {
    const labels = { box: "Куб", cylinder: "Цилиндр", sphere: "Сфера", cone: "Конус", plane: "Плоскость" };
    if (!PRIMITIVES.includes(primitive)) throw new Error("Неизвестный примитив.");
    return normalizePart({
      id: makeId(), name: labels[primitive], primitive,
      position: [0, 0.5, 0], rotation: [0, 0, 0],
      scale: [1, 1, 1], color: "#977256", metalness: 0, roughness: 0.85,
      ...overrides
    });
  }
  function normalizePart(value) {
    if (!value || typeof value !== "object" || Array.isArray(value))
      throw new Error("Некорректный объект детали.");
    if (!PRIMITIVES.includes(value.primitive)) throw new Error("Неизвестный примитив: " + value.primitive);
    const color = asString(value.color, 7, "Цвет").toLowerCase();
    if (!/^#[0-9a-f]{6}$/.test(color)) throw new Error("Цвет должен быть в формате #RRGGBB.");
    const name = asString(value.name, 90, "Название");
    if (!name) throw new Error("Название детали пустое.");
    return {
      id: ident(value.id), name, primitive: value.primitive,
      position: vector(value.position, -100, 100, "Позиция"),
      rotation: vector(value.rotation, -360, 360, "Поворот"),
      scale: vector(value.scale, 0.02, 40, "Масштаб"),
      color, metalness: number(value.metalness, 0, 1, "Металличность"),
      roughness: number(value.roughness, 0, 1, "Шероховатость")
    };
  }
  function normalizeProject(value) {
    if (!value || typeof value !== "object" || Array.isArray(value) ||
        value.format !== FORMAT || value.version !== VERSION ||
        value.units !== "meters" || !Array.isArray(value.parts) || value.parts.length > MAX_PARTS)
      throw new Error("Это не проект Model Lab версии 1 или превышен лимит деталей.");
    const name = asString(value.name, 90, "Название модели");
    if (!name) throw new Error("У модели должно быть название.");
    const parts = value.parts.map(normalizePart);
    const known = new Set();
    for (const part of parts) {
      if (known.has(part.id)) throw new Error("Повторяющийся ID детали: " + part.id);
      known.add(part.id);
    }
    return { format: FORMAT, version: VERSION, units: "meters", name, parts };
  }
  function makeProject(name = "Новая модель", parts = []) {
    return normalizeProject({ format: FORMAT, version: VERSION, units: "meters", name, parts });
  }
  function clonePart(part) {
    const copy = normalizePart(part);
    copy.id = makeId();
    copy.name = (copy.name + " копия").slice(0, 90);
    copy.position = [Math.min(100, copy.position[0] + 0.25), copy.position[1], copy.position[2]];
    return copy;
  }
  function preset(name) {
    if (name === "crate") {
      return makeProject("Старый деревянный ящик", [
        makePart("box", { name:"Корпус", color:"#70513b", position:[0,0.53,0], scale:[1.25,1.05,0.95] }),
        makePart("box", { name:"Передняя планка", color:"#a47a50", position:[0,0.53,0.49], scale:[1.24,0.16,0.08] }),
        makePart("box", { name:"Верхняя планка", color:"#b08c5c", position:[0,1.06,0], scale:[1.32,0.12,1.02] }),
        makePart("box", { name:"Левая стойка", color:"#9b774f", position:[-0.56,0.52,0.49], scale:[0.12,1.08,0.08] }),
        makePart("box", { name:"Правая стойка", color:"#9b774f", position:[0.56,0.52,0.49], scale:[0.12,1.08,0.08] })
      ]);
    }
    if (name === "lantern") {
      return makeProject("Уличный фонарь", [
        makePart("cylinder", { name:"Опора", color:"#384344", position:[0,1.55,0], scale:[0.20,3.1,0.20], metalness:0.7, roughness:0.48 }),
        makePart("cylinder", { name:"Основание", color:"#42413c", position:[0,0.20,0], scale:[0.48,0.40,0.48], metalness:0.5 }),
        makePart("box", { name:"Корпус светильника", color:"#333c3b", position:[0,3.26,0], scale:[0.64,0.48,0.64], metalness:0.5 }),
        makePart("box", { name:"Стекло", color:"#d7b98a", position:[0,3.25,0.33], scale:[0.46,0.29,0.05], roughness:0.18 }),
        makePart("cone", { name:"Крышка", color:"#42413c", position:[0,3.62,0], scale:[0.78,0.33,0.78], metalness:0.5 })
      ]);
    }
    if (name === "marker") {
      return makeProject("Дорожный указатель", [
        makePart("cylinder", { name:"Стойка", color:"#575b53", position:[0,1.1,0], scale:[0.12,2.2,0.12], metalness:0.65 }),
        makePart("box", { name:"Табличка", color:"#8f7556", position:[0,2.15,0], scale:[1.55,0.60,0.12] }),
        makePart("box", { name:"Верхняя окантовка", color:"#b99a70", position:[0,2.49,0], scale:[1.66,0.07,0.16] })
      ]);
    }
    throw new Error("Неизвестный шаблон.");
  }
  return Object.freeze({
    FORMAT, VERSION, PRIMITIVES, MAX_PARTS, PALETTE,
    makeId, makePart, normalizePart, makeProject, normalizeProject, clonePart, preset
  });
});
