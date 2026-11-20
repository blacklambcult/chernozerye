(() => {
  "use strict";
  window.chernozeryeLocalObjects = "";
  const library = window.ChernoObjectLibrary;
  function base64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result.split(",")[1]);
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(blob);
    });
  }
  async function load() {
    const placements = await library.placements();
    if (!placements.length) return { placements, models: [] };
    const ids = new Set(placements.map(item => item.modelId));
    const models = await Promise.all((await library.models()).filter(item => ids.has(item.id))
      .map(async item => ({ id: item.id, glb: await base64(item.blob) })));
    return { placements, models };
  }
  load().then(data => { window.chernozeryeLocalObjects = JSON.stringify(data); }).catch(error => {
    console.warn("В игре не удалось открыть локальную библиотеку", error);
    window.chernozeryeLocalObjects = "{}";
  });
})();
