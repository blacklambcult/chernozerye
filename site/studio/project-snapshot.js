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
    const [models, placements] = await Promise.all([library.models(), library.placements()]);
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
})();
