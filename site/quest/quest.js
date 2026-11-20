/* QUEST LAB 0.4 — Quest steps + persistent world items with Geo Lab references. */
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
  let library = "quest";
  const objects = window.ChernoObjectLibrary;
  let localMarkers;
  let pendingPlacement = null;
  let draftMarker = null;
  let localModels = [];
  let selectedCharacterId = null;
  let selectedStepId = null;
  let selectedWorldItemId = null;
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
  function worldItem() {
    return project.worldItems.find((item) => item.id === selectedWorldItemId) || null;
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
      displayStatus("Сохранено · "+project.quests.length+" квестов / "+
        project.worldItems.length+" находок");
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
  function renderWorldItemList() {
    const items = project.worldItems.filter(item => item.type === library);
    $("world-item-count").textContent = String(items.length);
    $("world-item-list").innerHTML = items.length ?
      items.map(item =>
        '<button type="button" class="quest-card'+(item.id===selectedWorldItemId?" selected":"")+
        '" data-world-id="'+escapeHtml(item.id)+'"><span class="quest-symbol">✦</span>'+
        '<span><span class="quest-name">'+escapeHtml(item.title)+'</span>'+
        '<span class="quest-kind">'+(item.type==="note"?"ЗАПИСКА":"ПРЕДМЕТ")+
        ' · '+(item.target?"РАЗМЕЩЕНО":"НЕТ КООРДИНАТ")+'</span></span></button>'
      ).join("") :
      '<p class="empty-state">Находок пока нет. Создай записку или предмет и укажи точку на карте.</p>';
  }
  function renderWorldItemInspector() {
    const item=worldItem();
    $("world-item-fields").hidden=!item;
    if(!item)return;
    $("world-item-id").textContent="ID / "+item.id;
    $("world-item-title").value=item.title;
    $("world-item-body").value=item.body;
    $("world-item-body-label").textContent=item.type==="note"?
      "Полный текст записки":"Описание предмета";
    $("world-item-body").placeholder=item.type==="note"?
      "Что написано на бумаге? Этот текст появится в игровом архиве.":
      "Описание предмета для инвентаря / журнала";
    $("world-item-coords").textContent=item.target ?
      item.target.lat.toFixed(7)+", "+item.target.lon.toFixed(7) :
      "ТОЧКА НЕ НАЗНАЧЕНА";
    $("world-item-object-id").value=item.objectId;
    const link=item.objectId?manualIndex.get(item.objectId):null;
    $("world-item-link-state").textContent=link ?
      "✓ Привязано: "+Geo.objectLabel(link) :
      item.objectId?"Не найден в текущем черновике Geo Lab":"Свободная точка";
    $("world-item-link-state").classList.toggle("missing",!!item.objectId&&!link);
    $("world-go-to").disabled=!item.target;
    $("world-bind-geo").classList.toggle("active",mode==="object"&&!!item);
  }
  function addWorldItem(type) {
    if(project.worldItems.length>=C.MAX_WORLD_ITEMS){
      displayStatus("Лимит находок в одном проекте: "+C.MAX_WORLD_ITEMS,true);
      return;
    }
    const item=C.createWorldItem(type);
    project.worldItems.push(item);
    selectedWorldItemId=item.id;
    selectedStepId=null;
    persist();
    renderAll();
    setMode("world_place");
    $("world-item-title").focus();
    $("world-item-title").select();
  }
  function selectWorldItem(id) {
    const item=project.worldItems.find(x=>x.id===id);
    if(!item)return;
    library = item.type;
    selectedWorldItemId=id;
    selectedStepId=null;
    renderLibrary();
    renderWorldItemList();
    renderWorldItemInspector();
    renderStepInspector();
    renderMapPins();
    setMode("world_place");
    if(item.target&&map)map.setView([item.target.lat,item.target.lon],Math.max(map.getZoom(),17),{animate:false});
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
    $("step-fields").hidden = !item || !!selectedWorldItemId;
    if (!q || !item) return;
    $("step-index").textContent = "STEP " + String(selectedStepIndex(q) + 1).padStart(2, "0");
    $("step-type").value = item.type;
    $("step-title").value = item.title;
    $("step-text").value = item.text;
    $("step-object").value = item.objectId;
    const note = catalogNote(item);
    $("inline-step-type").hidden = !!note;
    $("linked-note-info").hidden = !note;
    $("linked-note-info").textContent = note ? "Записка из каталога · " + note.title : "";
    $("step-document-fields").hidden = !!note || item.type !== "collect";
    $("step-document-title").value = item.document?.title || "";
    $("step-document-body").value = item.document?.body || "";
    $("target-controls").hidden = !!note || item.type === "message";
    $("target-coords").textContent = item.target ?
      item.target.lat.toFixed(6) + ", " + item.target.lon.toFixed(6) : "Точка не выбрана";
    renderObjectState();
  }
  async function refreshLocalObjects() {
    try {
      const [models, placements] = await Promise.all([objects.models(), objects.placements()]);
      localModels = models;
      const picker = $("local-model");
      const selected = picker.value;
      picker.replaceChildren(...models.map(model => new Option(model.name, model.id)));
      if (models.some(model => model.id === selected)) picker.value = selected;
      $("place-local-model").disabled = !models.length;
      $("local-model-status").textContent = models.length ?
        "Размещения доступны в игре в этом профиле браузера." :
        "Сохрани модель в библиотеку из Model Lab.";
      const names = new Map(models.map(model => [model.id, model.name]));
      $("local-placements").replaceChildren();
      localMarkers?.clearLayers();
      for (const item of placements) {
        const name = names.get(item.modelId) || "Модель недоступна";
        if (localMarkers) {
          const label = document.createElement("span");
          label.textContent = name;
          window.L.circleMarker([item.lat, item.lon], { radius: 7, color: "#6bd3d6" })
            .bindTooltip(label).addTo(localMarkers);
        }
        const row = document.createElement("div");
        row.className = "two-buttons";
        const locate = document.createElement("button");
        locate.type = "button";
        locate.className = "button";
        locate.textContent = name;
        locate.onclick = () => map?.setView([item.lat, item.lon], 18);
        const remove = document.createElement("button");
        remove.type = "button";
        remove.className = "button";
        remove.textContent = "Удалить";
        remove.onclick = async () => {
          if (pendingPlacement?.id === item.id) cancelPlacement();
          try { await objects.removePlacement(item.id); await refreshLocalObjects(); }
          catch (error) { $("local-model-status").textContent = error.message; }
        };
        const edit = document.createElement("button");
        edit.type = "button";
        edit.className = "button";
        edit.textContent = "Изменить";
        edit.onclick = () => {
          locate.onclick();
          beginPlacement(item);
        };
        row.append(locate, edit, remove);
        $("local-placements").append(row);
      }
    } catch (error) {
      $("place-local-model").disabled = true;
      $("local-model-status").textContent = "Библиотека недоступна: " + error.message;
    }
  }
  function cancelPlacement() {
    pendingPlacement = null;
    draftMarker?.remove();
    draftMarker = null;
    void window.showPlacementPreview?.(null);
    $("local-placement-edit").hidden = true;
    $("local-model-status").textContent = "";
  }

  function placementDraft() {
    if (!pendingPlacement) return null;
    const { lat, lon } = pendingPlacement;
    const east = Number($("local-east").value);
    const north = Number($("local-north").value);
    const heading = Number($("local-heading").value);
    const scale = Number($("local-scale").value);
    return { ...pendingPlacement, heading, scale,
      lat: lat + north / 111320,
      lon: lon + east / (111320 * Math.cos(lat * Math.PI / 180)) };
  }

  function updatePlacementDraft() {
    const draft = placementDraft();
    if (!draft) return;
    for (const [id, suffix] of [["local-heading", "°"], ["local-scale", "×"],
      ["local-east", " м"], ["local-north", " м"]]) {
      $(id + "-value").textContent = $(id).value + suffix;
    }
    window.updatePlacementPreview?.(draft.heading, draft.scale);
    const hasPoint = Number.isFinite(draft.lat) && Number.isFinite(draft.lon);
    $("save-local-heading").disabled = !hasPoint;
    if (hasPoint && map) {
      draftMarker ??= window.L.circleMarker([draft.lat, draft.lon], {
        radius: 10, color: "#ffb863", fillOpacity: 0.8, interactive: false
      }).addTo(map);
      draftMarker.setLatLng([draft.lat, draft.lon]);
    }
  }

  function beginPlacement(item) {
    cancelPlacement();
    setMode("browse");
    pendingPlacement = { ...item };
    $("local-placement-edit").hidden = false;
    $("local-heading").value = item.heading ?? 0;
    $("local-scale").value = item.scale ?? 1;
    $("local-east").value = 0;
    $("local-north").value = 0;
    $("local-model-status").textContent = "Клик по карте задаёт опорную точку. Оранжевая метка показывает новую позицию.";
    updatePlacementDraft();
    const model = localModels.find(entry => entry.id === item.modelId);
    window.showPlacementPreview?.(model?.blob)?.catch(() => {
      $("local-model-status").textContent = "Не удалось показать модель в 3D.";
    });
  }

  $("place-local-model").addEventListener("click", () => {
    const modelId = $("local-model").value;
    if (modelId) beginPlacement({ modelId });
  });
  for (const id of ["local-heading", "local-scale", "local-east", "local-north"])
    $(id).addEventListener("input", updatePlacementDraft);
  $("save-local-heading").addEventListener("click", async () => {
    const draft = placementDraft();
    if (!draft || !Number.isFinite(draft.lat) || !Number.isFinite(draft.lon)) return;
    const editing = pendingPlacement;
    $("save-local-heading").disabled = true;
    try {
      await objects.savePlacement({ ...draft, id: draft.id || crypto.randomUUID() });
      if (editing === pendingPlacement) cancelPlacement();
      await refreshLocalObjects();
    } catch (error) {
      $("local-model-status").textContent = error.message;
      if (editing === pendingPlacement) $("save-local-heading").disabled = false;
    }
  });
  $("cancel-local-edit").addEventListener("click", cancelPlacement);

  $("share-local-world").addEventListener("click", async event => {
    const button = event.currentTarget;
    button.disabled = true;
    $("local-share-result").hidden = true;
    try {
      const hash = await objects.makeSnapshot();
      const link = new URL("../", location.href);
      link.hash = "world=" + hash;
      $("local-world-link").value = link.href;
      $("local-share-result").hidden = false;
      $("local-world-link").select();
    } catch (error) {
      $("local-model-status").textContent = error.message;
    } finally { button.disabled = false; }
  });

  function catalogNote(item) {
    return project.worldItems.find(note => note.id === item?.noteId);
  }
  function renderLibrary() {
    const isQuest = library === "quest";
    const isFind = library === "note" || library === "item";
    for (const tab of document.querySelectorAll("[data-library]"))
      tab.setAttribute("aria-pressed", String(tab.dataset.library === library));
    $("quest-library").hidden = !isQuest;
    $("quest-scenario").hidden = !isQuest;
    if (!isQuest) $("quest-fields").hidden = true;
    $("world-library").hidden = !isFind;
    $("local-object-library").hidden = library !== "item";
    $("character-library").hidden = library !== "character";
    $("world-library-title").textContent = library === "note" ? "Записки" : "Предметы";
    $("add-world-note").hidden = library !== "note";
    $("add-world-item").hidden = library !== "item";
    const notes = project.worldItems.filter(item => item.type === "note");
    $("catalog-note").replaceChildren(...notes.map(note => new Option(note.title, note.id)));
    $("catalog-note").disabled = !notes.length || !quest();
    renderCharacters();
    $("add-catalog-note").disabled = $("catalog-note").disabled;
  }
  function character() {
    return project.characters?.find(item => item.id === selectedCharacterId);
  }
  function renderCharacters() {
    const selected = character();
    $("character-list").innerHTML = (project.characters || []).map(item =>
      '<button type="button" class="quest-card' + (item === selected ? ' selected' : '') +
      '" data-character="' + escapeHtml(item.id) + '">' + escapeHtml(item.name) + '</button>'
    ).join("");
    $("character-fields").hidden = !selected;
    $("character-name").value = selected?.name ?? "";
    $("character-description").value = selected?.description ?? "";
  }
  function renderAll(recenter = false) {
    const q = quest();
    if(selectedWorldItemId&&!worldItem())selectedWorldItemId=null;
    if (!q) selectedStepId = null;
    else if (!q.steps.some((s) => s.id === selectedStepId)) selectedStepId = q.steps[0]?.id || null;
    renderQuests();
    renderQuestInspector();
    renderLibrary();
    renderSteps();
    renderStepInspector();
    renderWorldItemList();
    renderWorldItemInspector();
    renderMap();
    if (recenter && q && map) map.setView([q.spawn.lat, q.spawn.lon], 16, { animate: false });
  }
  function addQuest(type) {
    const q = C.createQuest(type);
    q.title = type === "main" ? "Новый главный квест" : "Новый побочный квест";
    project.quests.push(q);
    project.selectedId = q.id;
    selectedStepId = null;
    selectedWorldItemId = null;
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
    selectedWorldItemId = null;
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
    selectedWorldItemId = null;
    persist();
    renderAll(true);
  }
  function selectStep(id) {
    const q = quest();
    if (!q || !q.steps.some((s) => s.id === id)) return;
    selectedStepId = id;
    selectedWorldItemId = null;
    renderWorldItemList();
    renderWorldItemInspector();
    renderSteps();
    renderStepInspector();
    renderMap();
  }
  function setMode(next) {
    if (next !== "browse" && pendingPlacement) cancelPlacement();
    if (["step","object"].includes(next) && !worldItem() && (!step() || step().type === "message")) {
      displayStatus("Выбери задачу с географической целью, а не сообщение.", true);
      return;
    }
    if (["step", "object"].includes(next) && !worldItem() && step()?.noteId) {
      displayStatus("Точка задаётся в разделе «Записки».", true);
      return;
    }
    if (next === "world_place" && !worldItem()) {
      displayStatus("Сначала создай или выбери находку.",true);
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
      mode === "object" ? "Кликни на геообъект Geo Lab. Привязка сохранит ID для выбранной находки или шага." :
      mode === "world_place" ? "Кликни на карту, чтобы разместить постоянную находку. Её можно передвигать за маркер." :
      mode === "step" ? "Кликни на карту, чтобы привязать выбранный шаг к местности." : "Просмотр карты";
    $("map-hint").classList.toggle("picking", mode==="object");
    $("quest-map").classList.toggle("is-object-picking", mode==="object");
    $("quest-map").classList.toggle("is-placement",mode!=="object" && mode!=="browse");
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
    if (destination === "browse") return;
    const p = C.point({ lat: location.lat, lon: location.lng });
    if(destination==="world_place"){
      const item=worldItem();
      if(!item){displayStatus("Выбери находку перед размещением.",true);return;}
      item.target=p;
      item.objectId="";
      persist();
      renderWorldItemInspector();
      renderWorldItemList();
      renderMapPins();
      return;
    }
    const q = quest();
    if (!q) {
      displayStatus("Сначала создай квест.", true);
      return;
    }
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
    const item=worldItem()||step();
    const status=item&&Geo?Geo.resolveBinding(item,manualIndex,C):null;
    if(!status?.entry||!status.point||!geoEnabled)return;
    const center=[status.point.lat,status.point.lon];
    objectHighlight=window.L.circleMarker(center,{
      radius:17,color:"#d8ffd4",weight:2,opacity:0.95,fillOpacity:0.04,
      dashArray:"4,4",interactive:false
    }).addTo(map);
  }
  function bindGeoObject(objectId) {
    const item=worldItem()||step();
    if(!item||item.type==="message"){displayStatus("Сначала выбери географическую задачу или находку.",true);return;}
    try {
      if(worldItem()){
        const entry=manualIndex.get(objectId);
        if(!entry)throw Error("Объект Geo Lab не найден");
        item.objectId=entry.id;
        item.target=C.point(entry.position);
      }else{
        const updated=Geo.bindStep(item,objectId,manualIndex,C);
        Object.assign(item,updated);
      }
      if(!persist())return;
      renderStepInspector();
      renderWorldItemInspector();
      renderWorldItemList();
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
    const item=worldItem()||step();
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
    const linked=[...project.worldItems,...project.quests.flatMap(q=>q.steps)];
    for(const item of linked){
      const match=Geo.resolveBinding(item,manualIndex,C);
      if(match.status==="moved"){
        item.target=match.point;
        changed=true;
      }
    }
    if(changed){
      persist();
      renderSteps();
      renderWorldItemList();
      renderWorldItemInspector();
      renderMapPins();
      console.info("QUEST_GEO_LINKS_UPDATED: manual_geometry_changed");
    }
  }
  function renderMapPins() {
    const q = quest();
    if (!map || !markers) return;
    markers.clearLayers();
    for(const item of project.worldItems){
      if(!item.target)continue;
      const selected=selectedWorldItemId===item.id;
      const marker=window.L.marker([item.target.lat,item.target.lon],{
        icon:makePin(selected?"world-active":"world"),draggable:selected
      }).addTo(markers).bindTooltip("✦ "+item.title);
      marker.on("click",()=>selectWorldItem(item.id));
      if(selected)marker.on("dragend",evt=>updatePoint(evt.target.getLatLng(),"world_place"));
    }
    if (!q) return;
    const spawnPin = window.L.marker([q.spawn.lat, q.spawn.lon], { icon: makePin("spawn"), draggable: true })
      .addTo(markers).bindTooltip("Старт игрока");
    spawnPin.on("dragend", (evt) => updatePoint(evt.target.getLatLng(), "spawn"));
    for (let i = 0; i < q.steps.length; i++) {
      const item = q.steps[i];
      if (item.noteId) continue; // The catalog pin already represents this location.
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
    setMode(["step","object"].includes(mode) && !worldItem() &&
      (!step() || step().type === "message") ? "spawn" : mode);
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
      renderWorldItemInspector();
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
    void refreshLocalObjects();
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
    localMarkers = L.layerGroup().addTo(map);
    void refreshLocalObjects();
    refreshGeoManual(true);
    void loadGeoPublished();
    $("geo-layer-toggle").addEventListener("click", toggleGeoLayers);
    map.on("click", evt => {
      if (pendingPlacement) {
        pendingPlacement.lat = evt.latlng.lat;
        pendingPlacement.lon = evt.latlng.lng;
        $("local-east").value = 0;
        $("local-north").value = 0;
        updatePlacementDraft();
        return;
      }
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


  for (const tab of document.querySelectorAll("[data-library]")) {
    tab.addEventListener("click", () => {
      if (pendingPlacement) cancelPlacement();
      library = tab.dataset.library;
      if (library === "item") void refreshLocalObjects();
      selectedWorldItemId = null;
      renderAll();
      setMode(library === "quest" ? "spawn" : "browse");
    });
  }
  $("character-list").addEventListener("click", event => {
    const button = event.target.closest("[data-character]");
    if (!button) return;
    selectedCharacterId = button.dataset.character;
    renderCharacters();
  });
  $("add-character").addEventListener("click", () => {
    project.characters ??= [];
    if (project.characters.length >= 150) {
      displayStatus("В проекте уже 150 персонажей.", true);
      return;
    }
    const id = C.makeId("character");
    project.characters.push({ id, name: "Новый персонаж", description: "" });
    selectedCharacterId = id;
    persist();
    renderCharacters();
    $("character-name").select();
  });
  $("character-name").addEventListener("change", event => {
    if (!character()) return;
    character().name = event.target.value.trim() || "Без имени";
    persist();
    renderCharacters();
  });
  $("character-description").addEventListener("input", event => {
    if (!character()) return;
    character().description = event.target.value;
    persist();
  });
  $("delete-character").addEventListener("click", () => {
    const item = character();
    if (!item || !window.confirm("Удалить персонажа «" + item.name + "»?")) return;
    project.characters = project.characters.filter(entry => entry !== item);
    selectedCharacterId = null;
    persist();
    renderCharacters();
  });
  $("add-catalog-note").addEventListener("click", () => {
    const q = quest();
    const note = project.worldItems.find(item => item.id === $("catalog-note").value);
    if (!q || !note) return;
    if (q.steps.some(item => item.noteId === note.id)) {
      displayStatus("Эта записка уже есть в квесте.", true);
      return;
    }
    const item = C.createStep("collect");
    item.title = "Найти: " + note.title.slice(0, 132);
    item.noteId = note.id;
    q.steps.push(item);
    selectedStepId = item.id;
    persist();
    renderAll();
    setMode("browse");
  });
  $("add-world-note").addEventListener("click",()=>addWorldItem("note"));
  $("add-world-item").addEventListener("click",()=>addWorldItem("item"));
  $("world-item-list").addEventListener("click",evt=>{
    const button=evt.target.closest("[data-world-id]");
    if(button)selectWorldItem(button.dataset.worldId);
  });
  $("world-item-title").addEventListener("input",evt=>{
    const item=worldItem();if(!item)return;
    item.title=evt.target.value;
    if(item.title.trim())persist();
    renderWorldItemList();
  });
  $("world-item-title").addEventListener("blur",()=>{
    const item=worldItem();if(!item)return;
    if(!item.title.trim()){item.title="Без названия";persist();renderWorldItemList();renderWorldItemInspector();}
  });
  $("world-item-body").addEventListener("input",evt=>{
    const item=worldItem();if(!item)return;
    item.body=evt.target.value;
    persist();
  });
  $("world-item-object-id").addEventListener("change",evt=>{
    const item=worldItem();if(!item)return;
    const id=evt.target.value.trim();
    if(!id){item.objectId="";persist();renderWorldItemInspector();renderMapPins();return;}
    if(manualIndex.has(id)){bindGeoObject(id);setMode("world_place");return;}
    displayStatus("ID не найден в открытой разметке Geo Lab. Не сохранено.",true);
    renderWorldItemInspector();
  });
  $("world-place").addEventListener("click",()=>setMode("world_place"));
  $("world-bind-geo").addEventListener("click",()=>setMode("object"));
  $("world-go-to").addEventListener("click",()=>{
    const item=worldItem();if(item?.target&&map){
      map.setView([item.target.lat,item.target.lon],Math.max(map.getZoom(),18),{animate:false});
    }
  });
  $("world-delete").addEventListener("click",()=>{
    const item=worldItem();
    if (item && project.quests.some(q => q.steps.some(step => step.noteId === item.id))) {
      displayStatus("Сначала убери связанные шаги из квестов.", true);
      return;
    }
    if(!item||!window.confirm("Удалить находку «"+item.title+"»?"))return;
    project.worldItems=project.worldItems.filter(x=>x.id!==item.id);
    selectedWorldItemId=null;
    persist();renderAll();setMode("spawn");
  });
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
    item.document = item.type === "collect" ? (item.document || {title:"",body:""}) : null;
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
  $("step-document-title").addEventListener("input", evt => {
    const item = step(); if (!item || item.type !== "collect") return;
    item.document ||= {title:"",body:""};
    item.document.title = evt.target.value;
    persist();
  });
  $("step-document-body").addEventListener("input", evt => {
    const item = step(); if (!item || item.type !== "collect") return;
    item.document ||= {title:"",body:""};
    item.document.body = evt.target.value;
    persist();
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
    displayStatus("JSON скачан · " + documentData.quests.length +
      " квестов / "+documentData.worldItems.length+" находок");
  });
  $("import-json").addEventListener("change", async (evt) => {
    const file = evt.target.files?.[0];
    evt.target.value = "";
    if (!file) return;
    if (file.size > 1024 * 1024) { displayStatus("Файл слишком большой (лимит 1 МБ).", true); return; }
    try {
      const imported = C.normalizeProject(JSON.parse(await file.text()));
      if ((project.quests.length||project.worldItems.length||project.characters?.length) &&
          !window.confirm("Импорт заменит квесты и находки. Продолжить?")) return;
      project = imported;
      selectedStepId = null;
      selectedWorldItemId = null;
      mode="spawn";
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
