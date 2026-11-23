/* CHERNOZERYE / GEO CONSTRUCTOR 2.0
 * Manual roads, paths, water, forest, plot boundaries and object footprints.
 * Browser-only drafts; GeoJSON export/import is the durable transfer format.
 */
(() => {
  "use strict";
  const api = window.ChernozeryeGeoLab;
  const core = window.GeoLabEditorCore;
  const $ = (id) => document.getElementById(id);
  if (!api?.map || !core) {
    console.error("Geo Lab editor: map or geometry helpers missing");
    const status = $("editor-save-status");
    if (status) status.textContent = "Конструктор не инициализирован. Обнови страницу.";
    return;
  }

  const map = api.map;
  const STORAGE_KEY = "chernozerye_manual_geojson_v2";
  const records = [];
  const rendered = new Map();
  let gameFeatures = [];
  let gameLayer;
  let selectedId = null;
  let activeTool = null;
  let draftPoints = [];
  let cursorPoint = null;
  let editingVertices = false;
  let insertingVertex = false;
  let selectedVertex = null;
  let savedMessage = "";
  let localStorageAvailable = true;

  for (const [name, z] of [["game-survey", 520], ["manual-survey", 532], ["manual-handles", 660]]) {
    if (!map.getPane(name)) map.createPane(name);
    map.getPane(name).style.zIndex = String(z);
  }

  const featureGroup = L.featureGroup().addTo(map);
  const draftGroup = L.layerGroup().addTo(map);
  const vertexGroup = L.layerGroup().addTo(map);
  const featureStyles = {
    road: { weight: 5.5, opacity: 0.95 },
    path: { weight: 3.1, opacity: 1, dashArray: "7,7" },
    water: { weight: 2.2, fillOpacity: 0.35 },
    forest: { weight: 2.2, fillOpacity: 0.25 },
    plot: { weight: 2.2, fillOpacity: 0.08, dashArray: "7,5" },
    object: { weight: 2.3, fillOpacity: 0.27 },
    house: { weight: 2.5, fillOpacity: 0.32 },
    shed: { weight: 2.5, fillOpacity: 0.32 },
    sauna: { weight: 2.5, fillOpacity: 0.3 },
    car: { weight: 2.5, fillOpacity: 0.4 }
  };

  function message(text, warning = false) {
    const node = $("editor-save-status");
    node.textContent = text;
    node.classList.toggle("warning", warning);
    savedMessage = text;
  }
  function countLabel(count) {
    const digit = count % 10, hundred = count % 100;
    return count + " " + (hundred >= 11 && hundred <= 14 ? "объектов"
      : digit === 1 ? "объект" : digit >= 2 && digit <= 4 ? "объекта" : "объектов");
  }
  function getRecord(id) {
    return records.find((item) => item.id === id) || null;
  }
  function uuid() {
    return typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : "manual-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10);
  }
  function asLatLng(position) {
    return L.latLng(position[1], position[0]);
  }
  function coordsFor(feature) {
    const geom = feature.geometry;
    if (geom.type === "Point") return [asLatLng(geom.coordinates)];
    const coords = geom.type === "Polygon"
      ? geom.coordinates[0].slice(0, -1) : geom.coordinates;
    return coords.map(asLatLng);
  }
  function rebuildCoordinates(feature, latlngs) {
    const pts = latlngs.map((point) => [Number(point.lng.toFixed(7)), Number(point.lat.toFixed(7))]);
    const type = feature.geometry.type;
    const geometry = type === "Point" ? { type, coordinates: pts[0] }
      : type === "Polygon" ? { type, coordinates: [pts] }
      : { type, coordinates: pts };
    const normalized = core.normalizeGeometry(geometry, feature.properties.category);
    if (!normalized) throw new Error("Не удалось обновить геометрию.");
    feature.geometry = normalized;
    feature.properties.updated_at = new Date().toISOString();
  }

  function styleFor(feature, selected = false) {
    const spec = core.TYPES[feature.properties.category];
    const style = Object.assign({
      color: spec.color,
      fillColor: spec.color,
      opacity: 0.95,
      weight: 2.5,
      fillOpacity: 0.24,
      lineCap: "round",
      lineJoin: "round"
    }, featureStyles[feature.properties.category] || {});
    if (selected) {
      style.weight += 1.5;
      style.color = "#fff4cf";
      style.fillOpacity = Math.max(style.fillOpacity, 0.34);
    }
    return style;
  }

  function makeLayer(feature) {
    const ll = coordsFor(feature);
    const style = styleFor(feature, feature.id === selectedId);
    let layer;
    if (feature.geometry.type === "Point") {
      layer = L.circleMarker(ll[0], { ...style, radius: 8.5, pane: "manual-survey" });
    } else if (feature.geometry.type === "Polygon") {
      layer = L.polygon(ll, { ...style, pane: "manual-survey" });
    } else {
      layer = L.polyline(ll, { ...style, pane: "manual-survey" });
    }
    layer.on("click", (event) => {
      if (activeTool || insertingVertex) return;
      L.DomEvent.stopPropagation(event);
      selectFeature(feature.id, false);
    });
    layer.bindTooltip(() => {
      const record = getRecord(feature.id);
      if (!record) return "Объект";
      return record.properties.name || core.TYPES[record.properties.category].label;
    }, { sticky: true, direction: "top" });
    return layer;
  }

  function refreshGameLayer() {
    if (!gameLayer) return;
    const draftIds = new Set($("editor-visible").checked ? records.map(feature => feature.id) : []);
    gameLayer.clearLayers();
    gameLayer.addData(gameFeatures.filter(feature => !draftIds.has(feature.id)));
  }

  async function loadGameLayer() {
    try {
      const response = await fetch("./data/game-map.geojson", { cache: "no-cache" });
      if (!response.ok) throw new Error("HTTP " + response.status);
      gameFeatures = core.importCollection(await response.json());
      gameLayer = L.geoJSON(null, {
        pane: "game-survey",
        interactive: false,
        style: feature => styleFor(feature),
        pointToLayer: (feature, position) => L.circleMarker(position, {
          ...styleFor(feature), pane: "game-survey", interactive: false, radius: 5
        })
      });
      refreshGameLayer();
      if ($("game-map-visible").checked) gameLayer.addTo(map);
      $("game-map-status").textContent = countLabel(gameFeatures.length) + " из текущей сборки";
      $("game-map-focus").disabled = $("game-map-copy").disabled = false;
    } catch (error) {
      $("game-map-status").textContent = "Игровая разметка недоступна. Обнови страницу.";
      console.warn("Geo Lab game map", error);
    }
  }

  $("game-map-visible").addEventListener("change", event => {
    if (!gameLayer) return;
    if (event.target.checked) gameLayer.addTo(map);
    else gameLayer.remove();
  });

  $("game-map-focus").addEventListener("click", () => {
    const bounds = L.latLngBounds(gameFeatures.flatMap(coordsFor));
    if (bounds.isValid()) map.fitBounds(bounds, { padding: [30, 30], maxZoom: 19 });
  });

  $("game-map-copy").addEventListener("click", () => {
    const ids = new Set(records.map(feature => feature.id));
    const additions = gameFeatures.filter(feature => !ids.has(feature.id));
    if (!additions.length) {
      message("Все объекты игровой карты уже есть в твоей разметке.");
      return;
    }
    records.push(...structuredClone(additions));
    $("editor-visible").checked = true;
    featureGroup.addTo(map);
    redrawAll();
    persist();
    if (localStorageAvailable) message("Добавлено в разметку: " + countLabel(additions.length) + ".");
  });

  function redrawFeature(id) {
    const prev = rendered.get(id);
    if (prev) featureGroup.removeLayer(prev);
    const feature = getRecord(id);
    if (!feature) {
      rendered.delete(id);
      return;
    }
    const layer = makeLayer(feature);
    rendered.set(id, layer);
    featureGroup.addLayer(layer);
  }

  function redrawAll() {
    featureGroup.clearLayers();
    rendered.clear();
    records.forEach((record) => redrawFeature(record.id));
    $("editor-count").textContent = countLabel(records.length);
    renderList();
    renderSelected();
  }

  function persist() {
    refreshGameLayer();
    try {
      const contents = core.collectionFromFeatures(records);
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(contents));
      localStorageAvailable = true;
      const time = new Date().toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });
      message("Автосохранено в этом браузере в " + time + " · " + countLabel(records.length));
    } catch (error) {
      localStorageAvailable = false;
      console.warn("Geo Lab autosave unavailable", error);
      message("Автосохранение недоступно. Скачай GeoJSON, чтобы сохранить работу!", true);
    }
  }

  function restore() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (!stored) {
        message("Черновик пуст. Автосохранение включено; для передачи скачай GeoJSON.");
        return;
      }
      const features = core.importCollection(JSON.parse(stored));
      records.push(...features);
      message("Восстановлен черновик: " + countLabel(features.length) + " · доступен в этом браузере.");
    } catch (error) {
      localStorageAvailable = false;
      console.warn("Geo Lab local data restore failed", error);
      message("Не удалось прочитать сохранённый черновик. Проверь скачанные GeoJSON-файлы.", true);
    }
  }

  function metric(feature) {
    if (feature.geometry.type === "Point") return "Метка";
    const m = core.measure(feature);
    if (feature.geometry.type === "LineString") return Math.round(m.length_m) + " м";
    return Math.round(m.area_m2) + " м²";
  }

  function renderList() {
    const node = $("editor-objects");
    node.replaceChildren();
    if (!records.length) {
      const paragraph = document.createElement("p");
      paragraph.className = "editor-empty";
      paragraph.textContent = "Объектов пока нет. Выбери инструмент и отметь первый.";
      node.appendChild(paragraph);
      return;
    }
    // Show the last created first; preserve underlying data order for stable export.
    for (const feature of [...records].reverse()) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "editor-list-item" + (selectedId === feature.id ? " is-selected" : "");
      const swatch = document.createElement("span");
      swatch.className = "editor-list-swatch";
      swatch.style.backgroundColor = core.TYPES[feature.properties.category].color;
      const text = document.createElement("span");
      text.className = "editor-list-title";
      text.textContent = feature.properties.name || core.TYPES[feature.properties.category].label;
      const detail = document.createElement("span");
      detail.className = "editor-list-metric";
      detail.textContent = metric(feature);
      button.append(swatch, text, detail);
      button.addEventListener("click", () => {
        cancelDrawing();
        selectFeature(feature.id, true);
      });
      node.appendChild(button);
    }
  }

  function buildCategoryOptions(feature) {
    const type = feature.geometry.type;
    const select = $("editor-type");
    select.replaceChildren();
    Object.entries(core.TYPES).forEach(([key, spec]) => {
      if (spec.geometry !== type && !(type === "Point" && spec.allowPoint)) return;
      const option = document.createElement("option");
      option.value = key;
      option.textContent = spec.label;
      option.selected = key === feature.properties.category;
      select.appendChild(option);
    });
  }

  function renderSelected() {
    const panel = $("editor-selected");
    const feature = getRecord(selectedId);
    panel.hidden = !feature;
    if (!feature) {
      $("editor-add-point").hidden = true;
      $("editor-remove-point").hidden = true;
      vertexGroup.clearLayers();
      return;
    }
    $("editor-name").value = feature.properties.name || "";
    $("editor-notes").value = feature.properties.notes || "";
    buildCategoryOptions(feature);
    const shape = feature.geometry.type === "Point" ? "точка"
      : feature.geometry.type === "LineString" ? "линия" : "полигон";
    $("editor-shape-info").textContent = "Геометрия: " + shape + " · " + metric(feature) +
      (editingVertices ? " · Перетаскивай белые точки. Щёлкни точку для удаления." : "");
    $("editor-edit-points").textContent = editingVertices ? "Завершить правку" : "Править точки";
    $("editor-add-point").hidden = !editingVertices || feature.geometry.type === "Point";
    $("editor-remove-point").hidden = !editingVertices || selectedVertex === null;
    $("editor-add-point").classList.toggle("is-active", insertingVertex);
    drawHandles();
  }

  function selectFeature(id, pan = false) {
    const previous = selectedId;
    selectedId = id;
    if (previous && rendered.has(previous)) redrawFeature(previous);
    editingVertices = false;
    insertingVertex = false;
    selectedVertex = null;
    vertexGroup.clearLayers();
    const feature = getRecord(id);
    if (feature) {
      redrawFeature(id);
      const layer = rendered.get(id);
      if (pan && layer) {
        if (feature.geometry.type === "Point") map.panTo(layer.getLatLng(), { animate: true });
        else map.fitBounds(layer.getBounds(), { maxZoom: 19, padding: [70, 70] });
      }
    }
    renderList();
    renderSelected();
  }

  function drawHandles() {
    vertexGroup.clearLayers();
    const feature = getRecord(selectedId);
    if (!editingVertices || !feature) return;
    coordsFor(feature).forEach((latlng, index) => {
      const icon = L.divIcon({
        className: "editor-vertex" + (index === selectedVertex ? " is-selected" : ""),
        iconSize: [15, 15], iconAnchor: [7.5, 7.5]
      });
      const marker = L.marker(latlng, {
        draggable: true, pane: "manual-handles", icon,
        autoPan: true, keyboard: false, riseOnHover: true
      });
      marker.on("click", (event) => {
        L.DomEvent.stopPropagation(event);
        selectedVertex = index;
        renderSelected();
      });
      marker.on("drag", (event) => {
        const source = getRecord(selectedId);
        if (!source) return;
        const vertices = coordsFor(source);
        vertices[index] = event.target.getLatLng();
        try {
          rebuildCoordinates(source, vertices);
          redrawFeature(source.id);
        } catch (error) {
          console.warn("Vertex drag rejected", error);
        }
      });
      marker.on("dragend", () => {
        persist();
        renderList();
        drawHandles();
      });
      vertexGroup.addLayer(marker);
    });
  }

  function cancelDrawing() {
    activeTool = null;
    draftPoints = [];
    cursorPoint = null;
    draftGroup.clearLayers();
    $("draw-actions").hidden = true;
    document.querySelectorAll(".editor-tool").forEach((button) => button.classList.remove("is-active"));
    map.getContainer().classList.remove("is-drawing");
    for (const paneName of ["overture", "osm", "nature", "study", "road"]) {
      const pane = map.getPane(paneName);
      if (pane) pane.style.pointerEvents = "";
    }
    if (!insertingVertex) map.doubleClickZoom.enable();
    $("draw-hint").textContent = "Выбери тип объекта. Точки ставятся щелчками по карте.";
  }

  function startDrawing(category, geometry) {
    if (!core.TYPES[category]) return;
    if (geometry !== core.TYPES[category].geometry && !(category === "car" && geometry === "Point")) return;
    cancelDrawing();
    editingVertices = false;
    insertingVertex = false;
    vertexGroup.clearLayers();
    renderSelected();
    activeTool = { category, geometry };
    draftPoints = [];
    cursorPoint = null;
    if (!$("editor-visible").checked) {
      $("editor-visible").checked = true;
      featureGroup.addTo(map);
    }
    map.doubleClickZoom.disable();
    map.closePopup();
    map.getContainer().classList.add("is-drawing");
    // Reference layers remain visible but must not steal clicks from drawing.
    for (const paneName of ["overture", "osm", "nature", "study", "road"]) {
      const pane = map.getPane(paneName);
      if (pane) pane.style.pointerEvents = "none";
    }
    const label = core.TYPES[category].label;
    $("draw-hint").textContent = geometry === "Point"
      ? "МЕТКА «" + label + "»: щёлкни место на карте."
      : "РИСУЕМ «" + label + "»: щёлкай по точкам на карте, затем «Завершить» (Enter).";
    $("draw-actions").hidden = geometry === "Point";
    document.querySelectorAll(".editor-tool").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.category === category && button.dataset.geometry === geometry);
    });
  }

  function redrawDraft() {
    draftGroup.clearLayers();
    if (!activeTool || !draftPoints.length || activeTool.geometry === "Point") return;
    const coords = cursorPoint ? [...draftPoints, cursorPoint] : draftPoints;
    const color = core.TYPES[activeTool.category].color;
    if (activeTool.geometry === "Polygon" && coords.length >= 3) {
      draftGroup.addLayer(L.polygon(coords, {
        pane: "manual-survey", color, weight: 2.5, dashArray: "5,4",
        fillOpacity: 0.18, interactive: false
      }));
    } else {
      draftGroup.addLayer(L.polyline(coords, {
        pane: "manual-survey", color, weight: 3.5, dashArray: "6,5", interactive: false
      }));
    }
    for (const p of draftPoints) {
      draftGroup.addLayer(L.circleMarker(p, {
        pane: "manual-survey", radius: 3.4, color: "#fff5d6",
        fillColor: color, fillOpacity: 1, weight: 1, interactive: false
      }));
    }
    const minimum = activeTool.geometry === "Polygon" ? 3 : 2;
    $("draw-finish").disabled = draftPoints.length < minimum;
    $("draw-undo").disabled = draftPoints.length === 0;
  }

  function onMapClick(event) {
    if (insertingVertex) {
      insertVertex(event.latlng);
      return;
    }
    if (!activeTool) return;
    if (activeTool.geometry === "Point") {
      createFeature([event.latlng]);
      cancelDrawing();
      return;
    }
    if (draftPoints.length && draftPoints[draftPoints.length - 1].distanceTo(event.latlng) < 0.65) return;
    draftPoints.push(event.latlng);
    cursorPoint = null;
    redrawDraft();
    const needed = activeTool.geometry === "Polygon" ? 3 : 2;
    $("draw-hint").textContent = core.TYPES[activeTool.category].label + ": точек " + draftPoints.length +
      (draftPoints.length >= needed ? " · можно завершить (Enter)" : " · добавь ещё " + (needed - draftPoints.length));
  }
  function createFeature(points) {
    if (!activeTool) return;
    const coordinates = points.map((p) => [Number(p.lng.toFixed(7)), Number(p.lat.toFixed(7))]);
    const g = activeTool.geometry === "Point"
      ? { type: "Point", coordinates: coordinates[0] }
      : activeTool.geometry === "LineString"
        ? { type: "LineString", coordinates }
        : { type: "Polygon", coordinates: [coordinates] };
    try {
      const feature = core.makeFeature(uuid(), activeTool.category, g);
      records.push(feature);
      redrawFeature(feature.id);
      persist();
      const newId = feature.id;
      cancelDrawing();
      selectFeature(newId, false);
    } catch (error) {
      message(error.message, true);
    }
  }
  function finishDrawing() {
    if (!activeTool) return;
    const needed = activeTool.geometry === "Point" ? 1 :
      activeTool.geometry === "LineString" ? 2 : 3;
    if (draftPoints.length < needed) {
      $("draw-hint").textContent = "Чтобы завершить, нужно не менее " + needed + " точек.";
      return;
    }
    createFeature(draftPoints);
  }
  function undoPoint() {
    if (!activeTool || !draftPoints.length) return;
    draftPoints.pop();
    redrawDraft();
    $("draw-hint").textContent = "Осталось точек: " + draftPoints.length;
  }

  map.on("click", onMapClick);
  map.on("dblclick", (event) => {
    if (activeTool && activeTool.geometry !== "Point") {
      L.DomEvent.preventDefault(event);
      finishDrawing();
    }
  });
  map.on("mousemove", (event) => {
    if (!activeTool || !draftPoints.length || activeTool.geometry === "Point") return;
    cursorPoint = event.latlng;
    redrawDraft();
  });
  document.querySelectorAll(".editor-tool").forEach((button) => {
    button.addEventListener("click", () => {
      const type = button.dataset.category;
      const geometry = button.dataset.geometry;
      if (activeTool && activeTool.category === type && activeTool.geometry === geometry) cancelDrawing();
      else startDrawing(type, geometry);
      button.blur(); // Enter should finish drawing, not reactivate a focused tool.
    });
  });
  $("draw-finish").addEventListener("click", finishDrawing);
  $("draw-undo").addEventListener("click", undoPoint);
  $("draw-cancel").addEventListener("click", cancelDrawing);

  function nearestSegmentIndex(points, at, closePolygon) {
    const atPx = map.latLngToLayerPoint(at);
    let bestDistance = Infinity, bestIndex = -1;
    const segmentCount = closePolygon ? points.length : points.length - 1;
    for (let i = 0; i < segmentCount; i++) {
      const a = map.latLngToLayerPoint(points[i]);
      const b = map.latLngToLayerPoint(points[(i + 1) % points.length]);
      const dx = b.x - a.x, dy = b.y - a.y;
      const denom = dx * dx + dy * dy || 1;
      const t = Math.max(0, Math.min(1, ((atPx.x - a.x) * dx + (atPx.y - a.y) * dy) / denom));
      const dist = Math.hypot(atPx.x - (a.x + t * dx), atPx.y - (a.y + t * dy));
      if (dist < bestDistance) {
        bestDistance = dist;
        bestIndex = i + 1;
      }
    }
    return bestDistance <= 28 ? bestIndex : -1;
  }
  function insertVertex(latlng) {
    const feature = getRecord(selectedId);
    if (!feature || feature.geometry.type === "Point") return;
    const points = coordsFor(feature);
    const index = nearestSegmentIndex(points, latlng, feature.geometry.type === "Polygon");
    if (index < 0) {
      $("editor-shape-info").textContent = "Для новой вершины нажми ближе к линии (до 28 пикселей).";
      return;
    }
    points.splice(index, 0, latlng);
    try {
      rebuildCoordinates(feature, points);
      selectedVertex = index;
      redrawFeature(feature.id);
      persist();
      renderList();
      insertingVertex = false;
      map.doubleClickZoom.enable();
      renderSelected();
    } catch (error) {
      message(error.message, true);
    }
  }
  function removeVertex() {
    const feature = getRecord(selectedId);
    if (!feature || selectedVertex === null) return;
    const points = coordsFor(feature);
    const required = feature.geometry.type === "Polygon" ? 3 :
      feature.geometry.type === "LineString" ? 2 : 1;
    if (points.length <= required) {
      message("Для этой формы нужно оставить минимум " + required + " вершины.", true);
      return;
    }
    points.splice(selectedVertex, 1);
    try {
      rebuildCoordinates(feature, points);
      selectedVertex = null;
      redrawFeature(feature.id);
      persist();
      renderList();
      renderSelected();
    } catch (error) {
      message(error.message, true);
    }
  }

  $("editor-edit-points").addEventListener("click", () => {
    const feature = getRecord(selectedId);
    if (!feature) return;
    cancelDrawing();
    editingVertices = !editingVertices;
    insertingVertex = false;
    selectedVertex = null;
    renderSelected();
  });
  $("editor-add-point").addEventListener("click", () => {
    if (!editingVertices) return;
    insertingVertex = !insertingVertex;
    if (insertingVertex) {
      map.doubleClickZoom.disable();
      $("editor-shape-info").textContent = "Нажми рядом с линией на карте, чтобы вставить вершину.";
    } else {
      map.doubleClickZoom.enable();
      renderSelected();
    }
    $("editor-add-point").classList.toggle("is-active", insertingVertex);
  });
  $("editor-remove-point").addEventListener("click", removeVertex);

  $("editor-apply").addEventListener("click", () => {
    const feature = getRecord(selectedId);
    if (!feature) return;
    const category = $("editor-type").value;
    const geometry = core.normalizeGeometry(feature.geometry, category);
    if (!geometry) {
      message("Этот тип не подходит к форме выбранного объекта.", true);
      return;
    }
    feature.geometry = geometry;
    feature.properties.category = category;
    feature.properties.name = $("editor-name").value.trim().slice(0, 120);
    feature.properties.notes = $("editor-notes").value.trim().slice(0, 600);
    feature.properties.updated_at = new Date().toISOString();
    redrawFeature(feature.id);
    persist();
    renderList();
    renderSelected();
  });

  $("editor-delete").addEventListener("click", () => {
    const feature = getRecord(selectedId);
    if (!feature || !confirm("Удалить выбранный объект из разметки?")) return;
    const index = records.indexOf(feature);
    records.splice(index, 1);
    featureGroup.removeLayer(rendered.get(feature.id));
    rendered.delete(feature.id);
    selectedId = null;
    editingVertices = false;
    insertingVertex = false;
    selectedVertex = null;
    persist();
    redrawAll();
  });

  $("editor-visible").addEventListener("change", (event) => {
    refreshGameLayer();
    if (event.target.checked) featureGroup.addTo(map);
    else map.removeLayer(featureGroup);
    if (!event.target.checked) {
      editingVertices = false;
      vertexGroup.clearLayers();
      renderSelected();
    }
  });

  function downloadFile() {
    if (!records.length) {
      message("Сначала разметь хотя бы один объект.", true);
      return;
    }
    let content;
    try {
      content = JSON.stringify(core.collectionFromFeatures(records), null, 2) + "\n";
    } catch (error) {
      message("Проверь геометрию: " + error.message, true);
      return;
    }
    const blob = new Blob([content], { type: "application/geo+json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.download = "chernozerye-sector-" + (api.getView() === "a-street" ? "a-quarter" : "survey") +
      "-" + new Date().toISOString().slice(0, 10) + ".geojson";
    anchor.href = url;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    message("Файл GeoJSON подготовлен к скачиванию · " + countLabel(records.length) + ". Прикрепи его в чат.");
  }
  $("editor-export").addEventListener("click", downloadFile);

  $("editor-import-file").addEventListener("change", async (event) => {
    const input = event.target;
    const file = input.files && input.files[0];
    if (!file) return;
    try {
      if (file.size > 8_000_000) throw new Error("Файл слишком большой (максимум 8 МБ).");
      const raw = JSON.parse(await file.text());
      const features = core.importCollection(raw);
      if (records.length && !confirm("Заменить текущую разметку (" + countLabel(records.length) +
          ") объектами из файла (" + countLabel(features.length) + ")? Сначала скачай резервную копию.")) {
        return;
      }
      cancelDrawing();
      records.splice(0, records.length, ...features);
      selectedId = null;
      editingVertices = false;
      insertingVertex = false;
      selectedVertex = null;
      $("editor-visible").checked = true;
      featureGroup.addTo(map);
      redrawAll();
      persist();
      message("Импорт завершён: " + countLabel(records.length) + ". Разметка восстановлена.");
    } catch (error) {
      message("Ошибка импорта: " + error.message + ". Нужен GeoJSON из конструктора.", true);
    } finally {
      input.value = "";
    }
  });

  $("editor-clear").addEventListener("click", () => {
    if (!records.length) return;
    if (!confirm("Удалить ВСЮ ручную разметку (" + countLabel(records.length) +
        ")? Если она нужна, сначала скачай GeoJSON.")) return;
    cancelDrawing();
    records.length = 0;
    selectedId = null;
    editingVertices = false;
    insertingVertex = false;
    selectedVertex = null;
    redrawAll();
    persist();
  });

  document.addEventListener("keydown", (event) => {
    const tag = event.target?.tagName || "";
    if (["INPUT", "TEXTAREA", "SELECT"].includes(tag) || event.target?.isContentEditable) return;
    if (event.key === "Escape") {
      if (insertingVertex) {
        insertingVertex = false;
        map.doubleClickZoom.enable();
        renderSelected();
      } else if (activeTool) cancelDrawing();
      else if (editingVertices) {
        editingVertices = false;
        renderSelected();
      }
      return;
    }
    if (!activeTool) return;
    if (event.key === "Enter") {
      event.preventDefault();
      finishDrawing();
    } else if (event.key === "Backspace" || (event.key.toLowerCase() === "z" && (event.ctrlKey || event.metaKey))) {
      event.preventDefault();
      undoPoint();
    }
  });

  // Warm start without replacing read-only Overture/OSM layers.
  restore();
  redrawAll();
  void loadGameLayer();
  message(localStorageAvailable && !records.length
    ? "Черновик пуст. Изменения сохраняются в браузере; для передачи скачай GeoJSON."
    : savedMessage || "Конструктор готов.");
  console.info("CHERNOZERYE_EDITOR_READY", { version: "2.0", features: records.length });
})();
