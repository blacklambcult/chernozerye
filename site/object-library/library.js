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
  window.ChernoObjectLibrary = Object.freeze({
    models: () => access("models", "readonly", store => store.getAll()),
    placements: () => access("placements", "readonly", store => store.getAll()),
    saveModel: record => access("models", "readwrite", store => store.put(record)),
    savePlacement: record => access("placements", "readwrite", store => store.put(record)),
    removePlacement: id => access("placements", "readwrite", store => store.delete(id)),
    requestPersistence: async () => Boolean(await navigator.storage?.persist?.())
  });
})();
