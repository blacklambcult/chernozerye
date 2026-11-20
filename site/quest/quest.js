/* QUEST LAB 0.2 — Geo Lab object links via stable manual feature IDs. */
(() => {
  "use strict";
  const C = window.ChernoQuestCore;
  const Geo = window.ChernoQuestGeo;
  const GeoEditor = window.GeoLabEditorCore;
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
  let satellite = true;
  let storageWarning = "";
  let geoEnabled = true;
  let manualLayer = null;
  let manualRaw = undefined;
  let geoReadyCount = 0;
  let geoSourceFailures = 0;
  let manualCount = 0;
  let manualIndex = new Map();
  let pickLayer = null;
  let objectHighlight = null;
  const geoPublished = [];


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
  function renderObjectState() {
    const item = step();
    const status = Geo && item && item.type !== "message" ?
      Geo.resolveBinding(item, manualIndex, C) : {status:"empty"};
    const message = $("object-link-state");
    message.classList.toggle("linked", status.status === "linked" || status.status === "moved");
    message.classList.toggle("missing", status.status === "missing");
    const entry = status.entry;
    if(entry){
      message.textContent = "✓ "+Geo.objectLabel(entry)+" · ID: "+entry.id;
      $("object-link-icon").textContent="✓";
    }else if(status.status==="missing"){
      message.textContent="Объект "+item.objectId+" не найден в текущей разметке Geo Lab. Сохранённые координаты не удаляются.";
      $("object-link-icon").textContent="!";
    }else{
      message.textContent="Нет привязанного объекта Geo Lab";
      $("object-link-icon").textContent="◇";
    }
    $("find-geo-object").disabled=!entry;
    $("pick-geo-object").disabled=!item||item.type==="message";
    $("pick-geo-object").classList.toggle("active",mode==="object");
    renderObjectHighlight();
  }
  function renderObjectSearch() {
    const list=$("geo-object-results");
    const term=$("geo-object-search").value.trim();
    if(!term) {list.hidden=true;list.innerHTML="";return;}
    const results=Geo ? Geo.searchObjects(manualIndex,term,12) : [];
    list.hidden=false;
    list.innerHTML=results.length ? results.map(entry =>
      '<button type="button" class="geo-object-result" data-bind-geo="'+escapeHtml(entry.id)+'">'+
      '<span><strong>'+escapeHtml(Geo.objectLabel(entry))+'</strong>'+
      '<small>'+escapeHtml(entry.id)+'</small></span><span>↗</span></button>'
    ).join("") : '<p class="geo-object-results-empty">Совпадений нет. Проверь разметку Geo Lab или выбери объект на карте.</p>';
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
    renderObjectState();
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
    if (["step","object"].includes(next) && (!step() || step().type === "message")) {
      displayStatus("Выбери задачу с географической целью, а не сообщение.", true);
      return;
    }
    if (next === "object" && !manualIndex.size) {
      displayStatus("В Geo Lab пока нет доступной ручной разметки. Сначала нарисуй объекты на карте.", true);
      return;
    }
    if(next === "object" && !geoEnabled) toggleGeoLayers();
    mode = next;
    for (const button of document.querySelectorAll("[data-mode]")) {
      const active = button.dataset.mode === next;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    }
    $("map-hint").textContent = mode === "spawn" ?
      "Кликни на карту, чтобы установить стартовую позицию игрока." :
      mode === "object" ? "Кликни на контур дома, участка, леса или другого объекта Geo Lab. ID и координаты шага заполнятся автоматически." :
      "Кликни на карту, чтобы привязать выбранный шаг к местности.";
    $("map-hint").classList.toggle("picking", mode==="object");
    $("quest-map").classList.toggle("is-object-picking", mode==="object");
    $("quest-map").classList.toggle("is-placement",mode!=="object");
    updatePickVisibility();
    $("pick-geo-object").classList.toggle("active", mode==="object");
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
      // A manually placed target is a free coordinate, not an old object link.
      item.objectId = "";
      $("step-object").value = "";
      $("target-coords").textContent = p.lat.toFixed(6) + ", " + p.lon.toFixed(6);
      renderObjectState();
    }
    persist();
    renderSteps();
    renderMapPins();
  }
  function renderObjectHighlight() {
    if(!map || !window.L)return;
    if(objectHighlight){map.removeLayer(objectHighlight);objectHighlight=null;}
    const item=step();
    const status=item&&Geo?Geo.resolveBinding(item,manualIndex,C):null;
    if(!status?.entry||!status.point||!geoEnabled)return;
    const center=[status.point.lat,status.point.lon];
    objectHighlight=window.L.circleMarker(center,{
      radius:17,color:"#d8ffd4",weight:2,opacity:0.95,fillOpacity:0.04,
      dashArray:"4,4",interactive:false
    }).addTo(map);
  }
  function bindGeoObject(objectId) {
    const item=step();
    if(!item||item.type==="message"){displayStatus("Сначала выбери географическую задачу.",true);return;}
    try {
      const updated=Geo.bindStep(item,objectId,manualIndex,C);
      Object.assign(item,updated);
      if(!persist())return;
      renderStepInspector();
      renderSteps();
      renderMapPins();
      $("geo-object-search").value="";
      renderObjectSearch();
      const entry=manualIndex.get(objectId);
      displayStatus("Объект привязан к задаче: "+Geo.objectLabel(entry));
      console.info("QUEST_GEO_OBJECT_LINKED: "+objectId);
    }catch(error){displayStatus(error.message,true);}
  }
  function focusGeoObject() {
    const item=step();
    const match=item&&Geo?Geo.resolveBinding(item,manualIndex,C):null;
    if(!match?.entry||!map)return;
    map.setView([match.point.lat,match.point.lon],Math.max(map.getZoom(),18),{animate:false});
    renderObjectHighlight();
  }
  function createPickLayer(features,index) {
    if(!map||!window.L)return null;
    const L=window.L;
    return L.geoJSON({type:"FeatureCollection",features},{
      renderer:L.canvas({padding:0.4}),interactive:true,
      style(feature) {
        const style=Geo.manualStyle(feature.properties?.category);
        return {...style,weight:Math.max(3,style.weight||2),
          opacity:1,fillOpacity:0.23,dashArray:"5,4"};
      },
      pointToLayer(_feature,latlng){
        return L.circleMarker(latlng,{radius:12,color:"#b6e7ba",
          fillColor:"#5b9e6a",weight:3,fillOpacity:.4,interactive:true});
      },
      onEachFeature(feature,layer){
        const entry=index.get(feature.id);
        if(!entry)return;
        layer.bindTooltip(escapeHtml(Geo.objectLabel(entry)),{
          sticky:true,className:"geo-pick-tooltip",direction:"top"});
        layer.on("click",evt=>{
          if(evt.originalEvent)L.DomEvent.stopPropagation(evt.originalEvent);
          if(mode==="object")bindGeoObject(entry.id);
        });
      }
    });
  }
  function updatePickVisibility(){
    if(!map)return;
    if(pickLayer){
      if(mode==="object"&&geoEnabled){if(!map.hasLayer(pickLayer))pickLayer.addTo(map);}
      else if(map.hasLayer(pickLayer))map.removeLayer(pickLayer);
    }
    if(markers){
      if(mode==="object"&&map.hasLayer(markers))map.removeLayer(markers);
      else if(mode!=="object"&&!map.hasLayer(markers))markers.addTo(map);
    }
  }
  function reconcileGeoLinks(){
    let changed=false;
    for(const q of project.quests)for(const item of q.steps){
      const match=Geo.resolveBinding(item,manualIndex,C);
      if(match.status==="moved"){
        item.target=match.point;
        changed=true;
      }
    }
    if(changed){
      persist();
      renderSteps();
      renderMapPins();
      console.info("QUEST_GEO_LINKS_UPDATED: manual_geometry_changed");
    }
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
    setMode(["step","object"].includes(mode) && (!step() || step().type === "message") ? "spawn" : mode);
  }
  function updateGeoStatus() {
    if (!Geo || !GeoEditor) {
      $("geo-layer-status").textContent = "GEO LAB / МОДУЛЬ НЕДОСТУПЕН";
      $("geo-layer-status").classList.add("warning");
      return;
    }
    const suffix = geoSourceFailures ? " · часть слоёв недоступна" : "";
    $("geo-layer-status").textContent = "GEO LAB / " + manualCount +
      " МОИХ · " + geoReadyCount + "/" + Geo.SOURCES.length + " БАЗОВЫХ" + suffix;
    $("geo-layer-status").classList.toggle("warning", geoSourceFailures > 0);
  }

  function makeGeoLayer(features, styleFn) {
    if (!map || !window.L) return null;
    // Noninteractive Canvas geometry lets clicks pass through to mission markers.
    // High-vertex surveys remain a backdrop rather than stealing quest-map events.
    return window.L.geoJSON(features, {
      interactive: false,
      renderer: window.L.canvas({ padding:0.4 }),
      style: styleFn,
      pointToLayer: (_feature, latlng) => window.L.circleMarker(latlng, {
        radius:4, color:"#aecfd6", weight:1, fillOpacity:0.65, interactive:false
      })
    });
  }
  function refreshGeoManual(force = false) {
    if (!map || !Geo || !GeoEditor) return;
    let raw;
    try { raw = window.localStorage.getItem(Geo.STORAGE_KEY); }
    catch {
      $("geo-layer-status").textContent = "GEO LAB / НЕТ ДОСТУПА К ХРАНИЛИЩУ";
      $("geo-layer-status").classList.add("warning");
      return;
    }
    if (!force && raw === manualRaw) return;
    // Preserve previously drawn overlay if storage unexpectedly becomes corrupted.
    try {
      const features = Geo.readManual(raw, GeoEditor);
      const next = makeGeoLayer({type:"FeatureCollection",features},feature =>
        Geo.manualStyle(feature.properties?.category));
      const nextIndex=Geo.objectIndex(features);
      const nextPick=createPickLayer(features,nextIndex);
      if(manualLayer&&map.hasLayer(manualLayer))map.removeLayer(manualLayer);
      if(pickLayer&&map.hasLayer(pickLayer))map.removeLayer(pickLayer);
      manualLayer=next;
      manualIndex=nextIndex;
      pickLayer=nextPick;
      manualRaw=raw;
      if(geoEnabled&&manualLayer)manualLayer.addTo(map);
      manualCount=features.length;
      updatePickVisibility();
      reconcileGeoLinks();
      renderObjectState();
      renderObjectSearch();
      updateGeoStatus();
    } catch (error) {
      console.warn("QUEST_GEO_MANUAL_INVALID", error);
      $("geo-layer-status").textContent = "GEO LAB / ПРОВЕРЬ ЧЕРНОВИК";
      $("geo-layer-status").classList.add("warning");
    }
  }
  async function loadGeoPublished() {
    if (!map || !Geo) return;
    await Promise.all(Geo.SOURCES.map(async spec => {
      try {
        const response = await fetch("../map/data/" + spec.file, { cache:"default" });
        if (!response.ok) throw new Error("HTTP " + response.status);
        const documentData = await response.json();
        const size = Geo.sourceCounts(documentData);
        const layer = makeGeoLayer(documentData, () => Geo.sourceStyle(spec.id));
        geoPublished.push(layer);
        geoReadyCount++;
        if (geoEnabled && layer) layer.addTo(map);
        console.info("QUEST_GEO_LAYER_READY: " + spec.id + " features=" + size);
      } catch (error) {
        geoSourceFailures++;
        console.warn("QUEST_GEO_LAYER_FAILED", spec.file, error);
      }
      updateGeoStatus();
    }));
    refreshGeoManual();
  }
  function toggleGeoLayers() {
    geoEnabled = !geoEnabled;
    for (const layer of [...geoPublished,manualLayer]) {
      if (!layer) continue;
      if (geoEnabled) { if (!map.hasLayer(layer)) layer.addTo(map); }
      else if (map.hasLayer(layer)) map.removeLayer(layer);
    }
    $("geo-layer-toggle").classList.toggle("active", geoEnabled);
    $("geo-layer-toggle").setAttribute("aria-pressed", String(geoEnabled));
    $("geo-layer-toggle").textContent = geoEnabled ? "▥ Геообъекты" : "▤ Показать слои";
    updatePickVisibility();
    renderObjectHighlight();
  }
  // The Studio keeps Quest Lab alive in an iframe while editing Geo Lab in
  // another. Refresh the same Geo Lab localStorage data every time it opens.
  window.QuestGeoOverlayRefresh = () => {
    refreshGeoManual();
    if (map) window.requestAnimationFrame(() => map.invalidateSize());
  };
  window.addEventListener("storage", evt => {
    if (Geo && evt.key === Geo.STORAGE_KEY) refreshGeoManual();
  });
  window.addEventListener("focus", () => refreshGeoManual());

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
    });
    satelliteTiles = L.tileLayer(
      "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
        maxZoom: 19, attribution: "Esri World Imagery"
      }).addTo(map);
    markers = L.layerGroup().addTo(map);
    refreshGeoManual(true);
    void loadGeoPublished();
    $("geo-layer-toggle").addEventListener("click", toggleGeoLayers);
    map.on("click", evt => {
      if(mode==="object"){
        displayStatus("Выбери окрашенный контур из разметки Geo Lab, а не пустую точку карты.",true);
        return;
      }
      updatePoint(evt.latlng);
    });
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
  $("step-object").addEventListener("input", evt => {
    const item=step();if(!item)return;
    item.objectId=evt.target.value.trim();
    if(manualIndex.has(item.objectId)){
      bindGeoObject(item.objectId);
    }else{
      persist();
      renderObjectState();
    }
  });
  $("geo-object-search").addEventListener("input",renderObjectSearch);
  $("geo-object-results").addEventListener("click",evt=>{
    const button=evt.target.closest("[data-bind-geo]");
    if(button)bindGeoObject(button.dataset.bindGeo);
  });
  $("pick-geo-object").addEventListener("click",()=>setMode("object"));
  $("find-geo-object").addEventListener("click",focusGeoObject);
  $("place-step").addEventListener("click", () => setMode("step"));
  $("clear-target").addEventListener("click", () => {
    const item = step(); if (!item) return;
    item.target = null;
    item.objectId = "";
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
