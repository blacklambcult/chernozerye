(() => {
  "use strict";
  function access(store, mode, operation) {
    return new Promise((resolve, reject) => {
      const open = indexedDB.open("chernozerye-object-library", 1);
      open.onupgradeneeded = () => {
        for (const name of ["models", "placements"])
          open.result.createObjectStore(name, { keyPath: "id" });
      };
      open.onerror = () => reject(open.error);
      open.onblocked = () => reject(new Error("Хранилище открыто в другой вкладке"));
      open.onsuccess = () => {
        const db = open.result;
        let tx;
        let request;
        try {
          tx = db.transaction(store, mode);
          request = operation(tx.objectStore(store));
        } catch (error) {
          db.close();
          reject(error);
          return;
        }
        tx.oncomplete = () => { db.close(); resolve(request.result); };
        tx.onabort = () => { db.close(); reject(tx.error || new Error("Запись отменена")); };
      };
    });
  }
  const MAX_LINK_LENGTH = 48000;
  function encode(bytes) {
    let binary = "";
    for (let offset = 0; offset < bytes.length; offset += 8192)
      binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
    return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  }
  async function makeSnapshot() {
    const library = window.ChernoObjectLibrary;
    const placements = await library.placements();
    const ids = new Set(placements.map(item => item.modelId));
    const models = await Promise.all((await library.models()).filter(model => ids.has(model.id))
      .map(async model => ({ id: model.id, glb: encode(new Uint8Array(await model.blob.arrayBuffer()))
        .replaceAll("-", "+").replaceAll("_", "/") })));
    for (const model of models) model.glb = model.glb.padEnd(Math.ceil(model.glb.length / 4) * 4, "=");
    const payload = new Blob([JSON.stringify({ version: 1, models, placements })]);
    const compressed = await new Response(payload.stream().pipeThrough(new CompressionStream("gzip"))).arrayBuffer();
    const fragment = encode(new Uint8Array(compressed));
    if (fragment.length > MAX_LINK_LENGTH) throw new Error("Снимок слишком большой для ссылки. Уменьши число или сложность моделей.");
    return fragment;
  }
  async function openSnapshot(fragment) {
    if (fragment.length > MAX_LINK_LENGTH || !/^[A-Za-z0-9_-]+$/.test(fragment))
      throw new Error("Некорректная ссылка на мир");
    const bytes = Uint8Array.from(atob(fragment.replaceAll("-", "+").replaceAll("_", "/")), char => char.charCodeAt(0));
    const reader = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip")).getReader();
    const chunks = [];
    let size = 0;
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 2_000_000) { await reader.cancel(); throw new Error("Снимок слишком большой"); }
      chunks.push(value);
    }
    const data = JSON.parse(await new Blob(chunks).text());
    if (data.version !== 1 || !Array.isArray(data.models) || !Array.isArray(data.placements) ||
        data.models.length > 100 || data.placements.length > 500 ||
        data.models.some(model => typeof model?.id !== "string" ||
          typeof model.glb !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(model.glb)) ||
        data.placements.some(item => typeof item?.modelId !== "string" ||
          !Number.isFinite(item.lat) || Math.abs(item.lat) > 85 ||
          !Number.isFinite(item.lon) || Math.abs(item.lon) > 180 ||
          !Number.isFinite(item.heading ?? 0) || !Number.isFinite(item.scale ?? 1)))
      throw new Error("Повреждённый снимок мира");
    return data;
  }
  window.ChernoObjectLibrary = Object.freeze({
    makeSnapshot, openSnapshot,
    models: () => access("models", "readonly", store => store.getAll()),
    placements: () => access("placements", "readonly", store => store.getAll()),
    saveModel: record => access("models", "readwrite", store => store.put(record)),
    savePlacement: record => access("placements", "readwrite", store => store.put(record)),
    removePlacement: id => access("placements", "readwrite", store => store.delete(id)),
    requestPersistence: async () => Boolean(await navigator.storage?.persist?.())
  });
})();
