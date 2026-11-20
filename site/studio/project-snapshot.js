(() => {
  "use strict";
  const button = document.querySelector("#export-studio-project");
  const status = document.querySelector("#studio-project-status");
  const { KEYS, countFor } = window.ChernoStudioState;
  const forgeKeys = {
    gameModel: "chernozerye.forge.game-model.v1",
    viewmodel: "chernozerye.forge.game-viewmodel.v1"
  };

  function readDraft(key, label, validate = () => true) {
    const raw = localStorage.getItem(key);
    if (raw === null) return null;
    try {
      if (!validate(raw)) throw new Error("invalid draft");
      return JSON.parse(raw);
    } catch {
      throw new Error("Не удалось прочитать данные: " + label);
    }
  }

  function serializeModel(model) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve({ id: model.id, name: model.name, glb: reader.result.split(",")[1] });
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(model.blob);
    });
  }

  async function collectProject() {
    const editors = Object.fromEntries(Object.entries(KEYS).map(([label, key]) =>
      [label, readDraft(key, label, raw => countFor(label, raw) !== null)]));
    const forge = Object.fromEntries(Object.entries(forgeKeys).map(([label, key]) =>
      [label, readDraft(key, label)]));
    const library = window.ChernoObjectLibrary;
    const { models, placements } = await library.readProject();
    const ids = new Set(models.map(model => model.id));
    const missing = placements.find(item => !ids.has(item.modelId));
    if (missing) throw new Error("Нет модели для размещения «" + (missing.name || missing.id) + "».");
    return { format: "chernozerye.studio-project", version: 1, createdAt: new Date().toISOString(),
      editors, forge, placements, models: await Promise.all(models.map(serializeModel)) };
  }

  button.addEventListener("click", async () => {
    button.disabled = true;
    status.textContent = "Собираю снимок…";
    try {
      const project = await collectProject();
      const url = URL.createObjectURL(new Blob([JSON.stringify(project)], { type: "application/json" }));
      const link = document.createElement("a");
      link.href = url;
      link.download = "chernozerye-studio-project.json";
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      status.textContent = "Снимок скачан. Моделей: " + project.models.length +
        ", размещений: " + project.placements.length + ".";
    } catch (error) {
      status.textContent = error.message || "Не удалось собрать снимок.";
    } finally {
      button.disabled = false;
    }
  });
  function record(value) {
    return value && typeof value === "object" && !Array.isArray(value);
  }

  function decodeGlb(value) {
    const bytes = Uint8Array.from(atob(value), char => char.charCodeAt(0));
    const header = new DataView(bytes.buffer);
    if (bytes.length < 20 || header.getUint32(0, true) !== 0x46546c67 ||
        header.getUint32(4, true) !== 2 || header.getUint32(8, true) !== bytes.length)
      throw new Error("В снимке повреждена модель GLB.");
    return new Blob([bytes], { type: "model/gltf-binary" });
  }

  function prepareRestore(snapshot) {
    if (snapshot?.format !== "chernozerye.studio-project" || snapshot.version !== 1 ||
        !record(snapshot.editors) || !record(snapshot.forge) ||
        !Array.isArray(snapshot.models) || !Array.isArray(snapshot.placements))
      throw new Error("Выбери полный снимок проекта Studio версии 1.");
    const { editors, forge } = snapshot;
    const validators = {
      geo: value => window.GeoLabEditorCore.importCollection(value),
      quest: value => window.ChernoQuestCore.normalizeProject(value),
      model: value => window.ChernoModelCore.normalizeProject(value),
      forge: value => window.ChernoHellishForge.normalizeProject(value)
    };
    const updates = Object.entries(KEYS).map(([label, key]) => {
      if (!Object.hasOwn(editors, label)) throw new Error("В снимке отсутствует раздел " + label);
      const value = editors[label];
      if (value !== null) validators[label](value);
      return [key, value === null ? null : JSON.stringify(value)];
    });
    if (forge.gameModel !== null) {
      const model = forge.gameModel;
      if (!record(model) || model.version !== 1 || !["sidearm", "longarm"].includes(model.category))
        throw new Error("Некорректный игровой образец Кузни.");
      decodeGlb(model.glb);
      window.ChernoHellishForge.normalizeViewmodel(model.viewmodel);
      window.ChernoHellishForge.normalizeGameplay(model.gameplay, model.category);
    }
    if (forge.viewmodel !== null) {
      const profile = forge.viewmodel;
      if (profile?.format !== "chernozerye.forge.viewmodel" || profile.version !== 1 || !profile.viewmodel)
        throw new Error("Некорректный FP-профиль Кузни.");
      window.ChernoHellishForge.normalizeViewmodel(profile.viewmodel);
    }
    for (const [label, key] of Object.entries(forgeKeys))
      updates.push([key, forge[label] === null ? null : JSON.stringify(forge[label])]);
    const ids = new Set();
    const models = snapshot.models.map(model => {
      if (!model?.id || typeof model.id !== "string" || ids.has(model.id) || typeof model.name !== "string")
        throw new Error("В снимке пустой или повторяющийся ID модели.");
      ids.add(model.id);
      return { id: model.id, name: model.name, blob: decodeGlb(model.glb) };
    });
    const placementIds = new Set();
    const placements = snapshot.placements.map(item => {
      if (!item?.id || typeof item.id !== "string" || placementIds.has(item.id) || !ids.has(item.modelId) ||
          !Number.isFinite(item.lat) || Math.abs(item.lat) > 90 ||
          !Number.isFinite(item.lon) || Math.abs(item.lon) > 180 ||
          !Number.isFinite(item.heading ?? 0) || !Number.isFinite(item.scale ?? 1))
        throw new Error("Повреждено размещение или отсутствует его модель.");
      placementIds.add(item.id);
      return item;
    });
    return { updates, models, placements };
  }

  const restoreButton = document.querySelector("#restore-studio-project");
  const restoreFile = document.querySelector("#restore-studio-file");
  restoreButton.addEventListener("click", () => restoreFile.click());
  restoreFile.addEventListener("change", async () => {
    const file = restoreFile.files?.[0];
    restoreFile.value = "";
    if (!file) return;
    restoreButton.disabled = true;
    button.disabled = true;
    try {
      const { updates, models, placements } = prepareRestore(JSON.parse(await file.text()));
      const library = window.ChernoObjectLibrary;
      const current = await library.readProject();
      const previous = updates.map(([key]) => [key, localStorage.getItem(key)]);
      if ((previous.some(([, value]) => value !== null) || current.models.length || current.placements.length) &&
          !window.confirm("Восстановление заменит текущий проект в этом браузере. Продолжить?")) return;
      const write = ([key, value]) => value === null ? localStorage.removeItem(key) : localStorage.setItem(key, value);
      try {
        for (const [key] of updates) localStorage.removeItem(key);
        updates.forEach(write);
        await library.replaceProject(models, placements);
      } catch (error) {
        for (const [key] of updates) localStorage.removeItem(key);
        previous.forEach(write);
        throw error;
      }
      try { sessionStorage.setItem("chernozerye.studio-restore-status", "Проект восстановлен. Моделей: " + models.length +
        ", размещений: " + placements.length + "."); } catch {}
      location.reload();
    } catch (error) {
      status.textContent = "Не удалось восстановить проект: " + error.message;
    } finally {
      restoreButton.disabled = false;
      button.disabled = false;
    }
  });
  try {
    const restored = sessionStorage.getItem("chernozerye.studio-restore-status");
    if (restored) {
      status.textContent = restored;
      sessionStorage.removeItem("chernozerye.studio-restore-status");
    }
  } catch {}

  const play = document.querySelector("#play-studio-project");
  document.querySelector("#load-studio-project").addEventListener("click", () => play.click());
  play.addEventListener("change", async () => {
    const file = play.files?.[0];
    play.value = "";
    if (!file) return;
    try {
      if (file.size > 2500000) throw new Error("Снимок больше 2,5 МБ.");
      const raw = await file.text();
      const snapshot = JSON.parse(raw);
      if (snapshot?.format !== "chernozerye.studio-project" || snapshot.version !== 1)
        throw new Error("Выбери снимок проекта из Studio.");
      sessionStorage.setItem("chernozerye.studio-playtest.v1", raw);
      location.href = "../#studio-playtest";
    } catch (error) { status.textContent = error.message; }
  });
})();
