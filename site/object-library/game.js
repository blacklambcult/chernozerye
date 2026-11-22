(() => {
  "use strict";
  window.chernozeryeLocalObjects = "";
  const library = window.ChernoObjectLibrary;
  window.chernozeryeForgeSlots = null;
  library.forgeSlots().then(async records => {
    const results = await Promise.allSettled(records.map(async ({blob, sounds, ...record}) => {
      const clips = await Promise.allSettled(Object.entries(sounds ?? {}).map(async ([action, sound]) =>
        [action, {format:sound.format, data:await base64(sound.blob)}]));
      const latest = record.modelId ? await library.model(record.modelId).catch(() => null) : null;
      const pose = latest?.viewmodel ? {viewmodel:latest.viewmodel} : {};
      return {...record, ...pose, armsGlb:latest?.arms?.glb, glb:await base64(blob), sounds:Object.fromEntries(clips.flatMap(clip =>
        clip.status === "fulfilled" ? [clip.value] : []))};
    }));
    window.chernozeryeForgeSlots = JSON.stringify(results.flatMap(result =>
      result.status === "fulfilled" ? [result.value] : []));
  }).catch(error => {
    console.warn("Не удалось прочитать тестовые ячейки Кузни", error);
    window.chernozeryeForgeSlots = "[]";
  });
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
  window.chernozeryeLoadLocalObjects = () => {
    const source = location.hash.startsWith("#world=") ? library.openSnapshot(location.hash.slice(7)) : load();
    source.then(data => {
      window.chernozeryeLocalObjects = JSON.stringify(data);
    }).catch(error => {
      console.warn("В игре не удалось открыть локальную библиотеку", error);
      window.chernozeryeLocalObjects = "{}";
    });
  };
})();
