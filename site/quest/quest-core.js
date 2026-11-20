/* QUEST LAB 0.1: pure JSON project model, shared by the editor and Node tests. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.ChernoQuestCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const FORMAT = "chernozerye.questlab";
  const VERSION = 1;
  const STEP_TYPES = Object.freeze(["reach", "interact", "collect", "message"]);
  const QUEST_TYPES = Object.freeze(["main", "side"]);
  const MAX_QUESTS = 100;
  const MAX_STEPS = 100;
  const DEFAULT_SPAWN = Object.freeze({ lon: 55.852815, lat: 54.672897, bearing: 0 });

  function text(value, limit) {
    if (typeof value !== "string") throw new Error("Текстовое поле должно быть строкой.");
    if (value.length > limit) throw new Error("Поле длиннее " + limit + " символов.");
    return value.trim();
  }
  function id(value) {
    const out = text(value, 120);
    if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(out)) throw new Error("Неверный идентификатор.");
    return out;
  }
  function point(value) {
    if (value === null) return null;
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Неверная точка на карте.");
    if (typeof value.lon !== "number" || !Number.isFinite(value.lon) || Math.abs(value.lon) > 180 ||
        typeof value.lat !== "number" || !Number.isFinite(value.lat) || Math.abs(value.lat) > 90) {
      throw new Error("Ожидаются конечные координаты WGS84.");
    }
    return { lon: Math.round(value.lon * 1e7) / 1e7, lat: Math.round(value.lat * 1e7) / 1e7 };
  }
  function spawn(value) {
    const p = point(value);
    if (!p) throw new Error("Для старта игрока нужны координаты.");
    const bearing = value.bearing === undefined ? 0 : value.bearing;
    if (typeof bearing !== "number" || !Number.isFinite(bearing) || bearing < 0 || bearing >= 360) {
      throw new Error("Курс спавна должен быть от 0 до 359.99°.");
    }
    return { ...p, bearing };
  }
  function makeId(prefix) {
    const random = typeof crypto !== "undefined" && typeof crypto.randomUUID === "function" ?
      crypto.randomUUID().replace(/-/g, "") : Math.random().toString(36).slice(2) + Date.now().toString(36);
    return prefix + "-" + random;
  }
  function createStep(type = "reach", customId = makeId("step")) {
    if (!STEP_TYPES.includes(type)) throw new Error("Неизвестный тип задачи.");
    const labels = { reach: "Дойти до точки", interact: "Взаимодействовать", collect: "Найти предмет", message: "Сообщение" };
    return { id: customId, type, title: labels[type], text: "", target: null, objectId: "",
      document: type === "collect" ? { title: "", body: "" } : null };
  }
  function normalizeStep(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Неверная задача.");
    if (!STEP_TYPES.includes(value.type)) throw new Error("Неизвестный тип задачи.");
    const result = {
      id: id(value.id),
      type: value.type,
      title: text(value.title, 140),
      text: text(value.text ?? "", 1400),
      target: value.target === undefined ? null : point(value.target),
      objectId: text(value.objectId ?? "", 120),
      document: null
    };
    if (result.type === "collect" && value.document !== null && value.document !== undefined) {
      if (typeof value.document !== "object" || Array.isArray(value.document))
        throw new Error("У записки должны быть название и текст.");
      result.document = {
        title: text(value.document.title ?? "", 140),
        body: text(value.document.body ?? "", 4000)
      };
    }
    if (!result.title) throw new Error("У задачи должно быть название.");
    return result;
  }
  function createQuest(type = "main", customId = makeId("quest")) {
    if (!QUEST_TYPES.includes(type)) throw new Error("Неизвестный тип квеста.");
    return {
      id: customId, type, title: "Новый квест", description: "",
      spawn: { ...DEFAULT_SPAWN }, steps: []
    };
  }
  function normalizeQuest(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Неверный квест.");
    if (!QUEST_TYPES.includes(value.type)) throw new Error("Тип квеста должен быть главным или побочным.");
    if (!Array.isArray(value.steps) || value.steps.length > MAX_STEPS) throw new Error("Слишком много задач.");
    const result = {
      id: id(value.id),
      type: value.type,
      title: text(value.title, 140),
      description: text(value.description ?? "", 1200),
      spawn: spawn(value.spawn),
      steps: value.steps.map(normalizeStep)
    };
    if (!result.title) throw new Error("У квеста должно быть название.");
    const seen = new Set();
    for (const step of result.steps) {
      if (seen.has(step.id)) throw new Error("Повторяющийся ID задачи: " + step.id);
      seen.add(step.id);
    }
    return result;
  }
  function normalizeProject(value) {
    if (!value || typeof value !== "object" || Array.isArray(value) ||
        value.format !== FORMAT || value.version !== VERSION ||
        !Array.isArray(value.quests) || value.quests.length > MAX_QUESTS) {
      throw new Error("Это не файл Quest Lab версии 1.");
    }
    const quests = value.quests.map(normalizeQuest);
    const seen = new Set();
    for (const quest of quests) {
      if (seen.has(quest.id)) throw new Error("Повторяющийся ID квеста: " + quest.id);
      seen.add(quest.id);
    }
    const selectedId = typeof value.selectedId === "string" && seen.has(value.selectedId) ?
      value.selectedId : (quests[0]?.id || null);
    return { format: FORMAT, version: VERSION, coordinates: "WGS84", selectedId, quests };
  }
  function makeProject(quests = [], selectedId = null) {
    return normalizeProject({ format: FORMAT, version: VERSION, selectedId, quests });
  }
  function moveStep(quest, index, direction) {
    const normalized = normalizeQuest(quest);
    if (!Number.isInteger(index) || ![-1, 1].includes(direction)) throw new Error("Неверное перемещение.");
    const to = index + direction;
    if (index < 0 || to < 0 || to >= normalized.steps.length) return normalized;
    const [item] = normalized.steps.splice(index, 1);
    normalized.steps.splice(to, 0, item);
    return normalized;
  }
  return Object.freeze({
    FORMAT, VERSION, STEP_TYPES, QUEST_TYPES, DEFAULT_SPAWN,
    makeId, point, spawn, createStep, normalizeStep, createQuest, normalizeQuest,
    makeProject, normalizeProject, moveStep
  });
});
