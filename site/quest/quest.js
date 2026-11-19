/* QUEST LAB 0.1 — standalone browser editor. No backend or Godot writes. */
(() => {
  "use strict";
  const C = window.ChernoQuestCore;
  const KEY = "chernozerye.questlab.v1";
  const $ = (id) => document.getElementById(id);
  const TYPE_NAMES = { main: "ОСНОВНОЙ", side: "ПОБОЧНЫЙ" };
  const STEP_NAMES = { reach: "ПРИБЫТЬ", interact: "ВЗАИМОДЕЙСТВИЕ", collect: "ПРЕДМЕТ", message: "СООБЩЕНИЕ" };
  const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (char) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]));
  let project;
  let selectedStepId = null;
  let mode = "spawn";
  let map = null;
  let markers = null;
  let streetTiles = null;
  let satelliteTiles = null;
  let satellite = false;
  let storageWarning = "";

  if (!C) {
    $("save-state").textContent = "Ошибка: не загружен модуль данных Quest Lab.";
    return;
  }
  try {
    const raw = localStorage.getItem(KEY);
    project = raw ? C.normalizeProject(JSON.parse(raw)) : C.makeProject();
  } catch (err) {
    project = C.makeProject();
    storageWarning = "Повреждённые локальные данные не загружены. Скачай JSON перед очисткой браузера.";
  }

  function quest() { return project.quests.find((q) => q.id === project.selectedId) || null; }
  function step() {
    const q = quest();
    return q ? q.steps.find((s) => s.id === selectedStepId) || null : null;
  }
  function displayStatus(message, warning = false) {
    $("save-state").textContent = message;
    $("save-state").classList.toggle("warning", warning);
    $("status-detail").textContent = message;
  }
  function persist() {
    try {
      // Export and browser storage share the same validation logic.
      const checked = C.normalizeProject(project);
      localStorage.setItem(KEY, JSON.stringify(checked));
      project = checked;
      displayStatus("Сохранено локально · " + project.quests.length + " квестов");
      return true;
    } catch (err) {
      displayStatus("Не сохранено: " + err.message, true);
      return false;
    }
  }
  function selectedStepIndex(q) {
    return q ? q.steps.findIndex((s) => s.id === selectedStepId) : -1;
  }
  function renderQuests() {
    const container = $("quest-list");
    $("quest-count").textContent = project.quests.length;
    if (!project.quests.length) {
      container.innerHTML = '<p class="empty-state">Квестов пока нет. Создай главный или побочный — появятся настройки и карта.</p>';
      return;
    }
    container.innerHTML = project.quests.map((q) =>
      '<button class="quest-card' + (q.id === project.selectedId ? " selected" : "") +
      '" type="button" data-quest-id="' + escapeHtml(q.id) + '">' +
      '<span class="quest-symbol' + (q.type === "side" ? " side" : "") + '">' +
      (q.type === "main" ? "◆" : "◇") + '</span>' +
      '<span><span class="quest-name">' + escapeHtml(q.title) + '</span>' +
      '<span class="quest-kind">' + TYPE_NAMES[q.type] + ' · ' + q.steps.length +
      ' ШАГОВ</span></span></button>').join("");
  }
  function renderSteps() {
    const q = quest();
    const container = $("step-list");
    $("step-count").textContent = q ? q.steps.length : "0";
    $("add-step").disabled = !q;
    $("new-step-type").disabled = !q;
    if (!q) {
      container.innerHTML = '<p class="empty-state">Сначала выбери квест в библиотеке слева.</p>';
      return;
    }
    if (!q.steps.length) {
      container.innerHTML = '<p class="empty-state">Шагов нет. Добавь задачу или сообщение — они появятся здесь по порядку.</p>';
      return;
    }
    container.innerHTML = q.steps.map((item, i) =>
      '<div class="step-card' + (item.id === selectedStepId ? " selected" : "") + '">' +
      '<button class="step-select" type="button" data-select-step="' + escapeHtml(item.id) + '">' +
      '<span class="step-number">' + String(i + 1).padStart(2, "0") + '</span><span class="step-main">' +
      '<span class="step-name">' + escapeHtml(item.title) + '</span>' +
      '<span class="step-kind">' + STEP_NAMES[item.type] +
      (item.target ? ' · ТОЧКА ✓' : "") + '</span></span></button>' +
      '<span class="step-buttons">' +
      '<button class="mini-button" title="Вверх" aria-label="Переместить вверх" data-action="up" data-id="' + item.id + '"' +
      (i === 0 ? " disabled" : "") + '>↑</button>' +
      '<button class="mini-button" title="Вниз" aria-label="Переместить вниз" data-action="down" data-id="' + item.id + '"' +
      (i === q.steps.length - 1 ? " disabled" : "") + '>↓</button>' +
      '<button class="mini-button remove" title="Удалить" aria-label="Удалить шаг" data-action="delete" data-id="' + item.id + '">×</button>' +
      '</span></div>').join("");
  }
  function renderQuestInspector() {
    const q = quest();
    $("quest-fields").hidden = !q;
    $("map-quest-title").textContent = q ? q.title : "Выбери квест";
    if (!q) return;
    $("quest-title").value = q.title;
    $("quest-type").value = q.type;
    $("quest-description").value = q.description;
    $("spawn-lat").value = q.spawn.lat;
    $("spawn-lon").value = q.spawn.lon;
    $("spawn-bearing").value = q.spawn.bearing;
  }
  function renderStepInspector() {
    const q = quest(), item = step();
    $("step-fields").hidden = !item;
    if (!q || !item) return;
    $("step-index").textContent = "STEP " + String(selectedStepIndex(q) + 1).padStart(2, "0");
    $("step-type").value = item.type;
    $("step-title").value = item.title;
    $("step-text").value = item.text;
    $("step-object").value = item.objectId;
    $("target-controls").hidden = item.type === "message";
    $("target-coords").textContent = item.target ?
      item.target.lat.toFixed(6) + ", " + item.target.lon.toFixed(6) : "Точка не выбрана";
  }
  function renderAll(recenter = false) {
    const q = quest();
    if (!q) selectedStepId = null;
    else if (!q.steps.some((s) => s.id === selectedStepId)) selectedStepId = q.steps[0]?.id || null;
    renderQuests();
    renderQuestInspector();
    renderSteps();
    renderStepInspector();
    renderMap();
    if (recenter && q && map) map.setView([q.spawn.lat, q.spawn.lon], 16, { animate: false });
  }
  function addQuest(type) {
    const q = C.createQuest(type);
    q.title = type === "main" ? "Новый главный квест" : "Новый побочный квест";
    project.quests.push(q);
    project.selectedId = q.id;
    selectedStepId = null;
    mode = "spawn";
    persist();
    renderAll(true);
    $("quest-title").focus();
    $("quest-title").select();
  }
  function addStep() {
    const q = quest();
    if (!q) return;
    const item = C.createStep($("new-step-type").value);
    q.steps.push(item);
    selectedStepId = item.id;
    persist();
    renderAll();
    if (item.type !== "message") setMode("step");
    $("step-title").focus();
    $("step-title").select();
  }
  function selectQuest(id) {
    if (!project.quests.some((q) => q.id === id)) return;
    project.selectedId = id;
    selectedStepId = null;
    persist();
    renderAll(true);
  }
  function selectStep(id) {
    const q = quest();
    if (!q || !q.steps.some((s) => s.id === id)) return;
    selectedStepId = id;
    renderSteps();
    renderStepInspector();
    renderMap();
  }
  function setMode(next) {
    if (next === "step" && (!step() || step().type === "message")) {
      displayStatus("Выбери задачу с географической целью, а не сообщение.", true);
      return;
    }
    mode = next;
    for (const button of document.querySelectorAll("[data-mode]")) {
      const active = button.dataset.mode === next;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    }
    $("map-hint").textContent = mode === "spawn" ?
      "Кликни на карту, чтобы установить стартовую позицию игрока." :
      "Кликни на карту, чтобы привязать выбранный шаг к местности.";
    $("quest-map").classList.add("is-placement");
  }
  function makePin(kind) {
    return window.L.divIcon({
      className: "quest-pin", iconSize: kind === "secondary" ? [14, 14] : [25, 25],
      iconAnchor: kind === "secondary" ? [7, 7] : [12, 12],
      html: '<span class="pin-shape ' + (kind === "spawn" ? "" : kind) + '"></span>'
    });
  }
  function updatePoint(location, destination = mode) {
    const q = quest();
    if (!q) {
      displayStatus("Сначала создай квест.", true);
      return;
    }
    const p = C.point({ lat: location.lat, lon: location.lng });
    if (destination === "spawn") {
      q.spawn.lat = p.lat;
      q.spawn.lon = p.lon;
      $("spawn-lat").value = p.lat;
      $("spawn-lon").value = p.lon;
    } else {
      const item = step();
      if (!item || item.type === "message") return;
      item.target = p;
      $("target-coords").textContent = p.lat.toFixed(6) + ", " + p.lon.toFixed(6);
    }
    persist();
    renderSteps();
    renderMapPins();
  }
  function renderMapPins() {
    const q = quest();
    if (!map || !markers) return;
    markers.clearLayers();
    if (!q) return;
    const spawnPin = window.L.marker([q.spawn.lat, q.spawn.lon], { icon: makePin("spawn"), draggable: true })
      .addTo(markers).bindTooltip("Старт игрока");
    spawnPin.on("dragend", (evt) => updatePoint(evt.target.getLatLng(), "spawn"));
    for (let i = 0; i < q.steps.length; i++) {
      const item = q.steps[i];
      if (!item.target) continue;
      const active = selectedStepId === item.id;
      const marker = window.L.marker([item.target.lat, item.target.lon], {
        icon: makePin(active ? "target" : "secondary"), draggable: active
      }).addTo(markers).bindTooltip((i + 1) + " · " + item.title);
      marker.on("click", () => selectStep(item.id));
      if (active) marker.on("dragend", (evt) => updatePoint(evt.target.getLatLng(), "step"));
    }
  }
  function renderMap() {
    renderMapPins();
    setMode(mode === "step" && (!step() || step().type === "message") ? "spawn" : mode);
  }
  function initializeMap() {
    if (!window.L) {
      $("map-error").hidden = false;
      return;
    }
    const L = window.L;
    map = L.map("quest-map", { zoomControl: false, preferCanvas: true }).setView(
      [C.DEFAULT_SPAWN.lat, C.DEFAULT_SPAWN.lon], 16);
    L.control.zoom({ position: "bottomright" }).addTo(map);
    streetTiles = L.tileLayer("https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png", {
      maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> / CARTO'
    }).addTo(map);
    satelliteTiles = L.tileLayer(
      "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
        maxZoom: 19, attribution: "Esri World Imagery"
      });
    markers = L.layerGroup().addTo(map);
    // The shared Geo Lab data is a visual reference, not a duplicate database.
    fetch("../map/data/roads.geojson").then((res) => {
      if (!res.ok) throw new Error("missing terrain layer");
      return res.json();
    }).then((data) => L.geoJSON(data, { style: { color: "#b49060", weight: 1.6, opacity: 0.45 },
      interactive: false }).addTo(map)).catch(() => {});
    map.on("click", (evt) => updatePoint(evt.latlng));
    map.on("mousemove", (evt) => {
      $("pointer-coords").textContent = evt.latlng.lat.toFixed(6) + ", " + evt.latlng.lng.toFixed(6);
    });
    $("basemap-toggle").addEventListener("click", () => {
      satellite = !satellite;
      if (satellite) { map.removeLayer(streetTiles); satelliteTiles.addTo(map); }
      else { map.removeLayer(satelliteTiles); streetTiles.addTo(map); }
      $("basemap-toggle").textContent = satellite ? "◫ Схема" : "◫ Спутник";
    });
    setTimeout(() => map.invalidateSize(), 50);
  }

  $("add-main").addEventListener("click", () => addQuest("main"));
  $("add-side").addEventListener("click", () => addQuest("side"));
  $("quest-list").addEventListener("click", (evt) => {
    const button = evt.target.closest("[data-quest-id]");
    if (button) selectQuest(button.dataset.questId);
  });
  $("quest-title").addEventListener("input", (evt) => {
    const q = quest();
    if (!q) return;
    q.title = evt.target.value.trim();
    $("map-quest-title").textContent = q.title || "Без названия";
    renderQuests();
    if (q.title) persist();
  });
  $("quest-title").addEventListener("blur", () => {
    const q = quest();
    if (q && !q.title) { q.title = "Новый квест"; persist(); renderQuests(); $("quest-title").value = q.title; }
  });
  $("quest-type").addEventListener("change", (evt) => {
    const q = quest(); if (!q) return; q.type = evt.target.value; persist(); renderQuests();
  });
  $("quest-description").addEventListener("input", (evt) => {
    const q = quest(); if (!q) return; q.description = evt.target.value; persist();
  });
  for (const field of ["spawn-lat", "spawn-lon", "spawn-bearing"]) {
    $(field).addEventListener("change", () => {
      const q = quest(); if (!q) return;
      const raw = [ $("spawn-lon").value, $("spawn-lat").value, $("spawn-bearing").value ];
      try {
        if (raw.some((x) => x.trim() === "")) throw new Error("Заполни все координаты.");
        const next = C.spawn({ lon: Number(raw[0]), lat: Number(raw[1]), bearing: Number(raw[2]) });
        q.spawn = next;
        persist();
        renderMapPins();
      } catch (err) {
        displayStatus(err.message, true);
        renderQuestInspector();
      }
    });
  }
  $("show-spawn").addEventListener("click", () => {
    const q = quest(); if (q && map) map.setView([q.spawn.lat, q.spawn.lon], 17);
    setMode("spawn");
  });
  $("duplicate-quest").addEventListener("click", () => {
    const q = quest(); if (!q) return;
    const copy = JSON.parse(JSON.stringify(q));
    copy.id = C.makeId("quest");
    copy.title = (q.title.slice(0, 130) + " (копия)");
    copy.steps = copy.steps.map((s) => ({ ...s, id: C.makeId("step") }));
    project.quests.push(copy);
    project.selectedId = copy.id;
    selectedStepId = null;
    persist();
    renderAll(true);
  });
  $("delete-quest").addEventListener("click", () => {
    const q = quest();
    if (!q || !window.confirm('Удалить квест «' + q.title + '»?')) return;
    project.quests = project.quests.filter((entry) => entry.id !== q.id);
    project.selectedId = project.quests[0]?.id || null;
    selectedStepId = null;
    persist();
    renderAll(true);
  });
  $("add-step").addEventListener("click", addStep);
  $("step-list").addEventListener("click", (evt) => {
    const action = evt.target.closest("[data-action]");
    if (action) {
      const q = quest(); if (!q) return;
      const index = q.steps.findIndex((s) => s.id === action.dataset.id);
      if (index < 0) return;
      if (action.dataset.action === "delete") {
        q.steps.splice(index, 1);
        if (selectedStepId === action.dataset.id) selectedStepId = q.steps[Math.min(index, q.steps.length - 1)]?.id || null;
      } else {
        const moved = C.moveStep(q, index, action.dataset.action === "up" ? -1 : 1);
        q.steps = moved.steps;
      }
      persist(); renderAll();
      return;
    }
    const button = evt.target.closest("[data-select-step]");
    if (button) selectStep(button.dataset.selectStep);
  });
  $("step-type").addEventListener("change", (evt) => {
    const item = step(); if (!item) return;
    item.type = evt.target.value;
    if (item.type === "message") { item.target = null; item.objectId = ""; }
    persist(); renderSteps(); renderStepInspector(); renderMap();
  });
  $("step-title").addEventListener("input", (evt) => {
    const item = step(); if (!item) return;
    item.title = evt.target.value.trim();
    renderSteps();
    if (item.title) persist();
  });
  $("step-title").addEventListener("blur", () => {
    const item = step();
    if (item && !item.title) { item.title = "Новый шаг"; persist(); renderSteps(); $("step-title").value = item.title; }
  });
  $("step-text").addEventListener("input", (evt) => {
    const item = step(); if (!item) return; item.text = evt.target.value; persist();
  });
  $("step-object").addEventListener("input", (evt) => {
    const item = step(); if (!item) return; item.objectId = evt.target.value; persist();
  });
  $("place-step").addEventListener("click", () => setMode("step"));
  $("clear-target").addEventListener("click", () => {
    const item = step(); if (!item) return;
    item.target = null;
    persist(); renderSteps(); renderStepInspector(); renderMapPins();
  });
  for (const button of document.querySelectorAll("[data-mode]")) {
    button.addEventListener("click", () => setMode(button.dataset.mode));
  }

  $("export-json").addEventListener("click", () => {
    let documentData;
    try { documentData = C.normalizeProject(project); }
    catch (err) { displayStatus("Проверь названия квестов и шагов: " + err.message, true); return; }
    const file = new Blob([JSON.stringify(documentData, null, 2) + "\n"], { type: "application/json" });
    const url = URL.createObjectURL(file);
    const a = document.createElement("a");
    a.href = url;
    a.download = "chernozerye-questlab-v1.json";
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    displayStatus("Проект JSON скачан · " + documentData.quests.length + " квестов");
  });
  $("import-json").addEventListener("change", async (evt) => {
    const file = evt.target.files?.[0];
    evt.target.value = "";
    if (!file) return;
    if (file.size > 1024 * 1024) { displayStatus("Файл слишком большой (лимит 1 МБ).", true); return; }
    try {
      const imported = C.normalizeProject(JSON.parse(await file.text()));
      if (project.quests.length && !window.confirm("Импорт заменит текущие квесты. Продолжить?")) return;
      project = imported;
      selectedStepId = null;
      persist();
      renderAll(true);
      displayStatus("Импорт завершён · " + project.quests.length + " квестов");
    } catch (err) {
      displayStatus("Не удалось импортировать JSON: " + err.message, true);
    }
  });

  initializeMap();
  renderAll(true);
  if (storageWarning) displayStatus(storageWarning, true);
  else if (!localStorage.getItem(KEY)) displayStatus("Новый проект. Создай первый квест.");
})();
