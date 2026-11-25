(() => {
  "use strict";
  const State = window.ChernoStudioState;
  const $ = (id) => document.getElementById(id);
  if (!State) throw new Error("ChernoStudioState missing");
  const MODES = Object.freeze({
    home: {kicker:"SYSTEM / OVERVIEW", name:"ЦЕНТР УПРАВЛЕНИЯ"},
    geo: {kicker:"GEOGRAPHIC WORKSPACE / 01", name:"GEO LAB · РЕДАКТОР МЕСТНОСТИ", url:"../map/", file:"../map/?studio=1"},
    quest: {kicker:"MISSION WORKSPACE / 02", name:"QUEST LAB · РЕДАКТОР КВЕСТОВ", url:"../quest/", file:"../quest/?studio=1"},
    model: {kicker:"ASSET WORKSPACE / 03", name:"MODEL LAB · 3D-КОНСТРУКТОР", url:"../model/", file:"../model/?studio=1"},
    forge: {kicker:"ARMORY ASSET WORKSPACE / 04", name:"HELLISH FORGE · ИГРОВЫЕ МОДЕЛИ", url:"../forge/", file:"../forge/?studio=1"},
    npc: {kicker:"CHARACTER WORKSPACE / 09", name:"NPC LAB · РЕДАКТОР ПЕРСОНАЖЕЙ", url:"../npc/", file:"../npc/?studio=1"},
    nature: {kicker:"ENVIRONMENT / 08", name:"ГЕНЕРАТОР ПРИРОДЫ", url:"../nature-generator/", file:"../nature-generator/?studio=1"},
    buildings: {kicker:"ARCHITECTURE / 07", name:"ГЕНЕРАТОР ПОСТРОЕК", url:"../building-generator/?v=3", file:"../building-generator/?studio=1&v=3"},
    arms: {kicker:"FIRST PERSON / 06", name:"РУКИ ОТ ПЕРВОГО ЛИЦА", url:"../arms/", file:"../arms/?studio=1"},
    weapon: {kicker:"PROCEDURAL ARMORY / 05", name:"ГЕНЕРАТОР ОРУЖИЯ · 8 КЛАССОВ", url:"../weapon-generator/", file:"../weapon-generator/?studio=1"}
  });
  const COLLAPSE_KEY = "chernozerye.studio.rail-collapsed.v1";
  const cached = new Map();
  const embeddedDocuments = new WeakSet();
  let railCollapsed = false;
  function notifyEditorResize() {
    const current = cached.get(active);
    if (!current) return;
    requestAnimationFrame(() => {
      try {
        current.frame.contentWindow.dispatchEvent(new Event("resize"));
      } catch (err) { console.warn("STUDIO_RESIZE_FAILED",err); }
    });
  }
  function setRailCollapsed(collapsed) {
    railCollapsed = Boolean(collapsed);
    document.querySelector(".studio").classList.toggle("nav-collapsed", railCollapsed);
    const button = $("rail-toggle");
    button.setAttribute("aria-expanded", String(!railCollapsed));
    button.title = railCollapsed ? "Развернуть боковую панель (Ctrl+B)" : "Свернуть боковую панель (Ctrl+B)";
    $("rail-chevron").textContent = railCollapsed ? "»" : "«";
    document.querySelector(".rail-toggle-text").textContent = railCollapsed ? "РАЗВЕРНУТЬ" : "СВЕРНУТЬ МЕНЮ";
    try { localStorage.setItem(COLLAPSE_KEY, String(railCollapsed)); }
    catch { /* shell navigation still functions without storage */ }
    notifyEditorResize();
  }
  try { railCollapsed = localStorage.getItem(COLLAPSE_KEY) === "true"; }
  catch { /* storage not available: start expanded */ }

  let active = null;
  const refreshStats = () => {
    let storage;
    try { storage = window.localStorage; } catch { storage = null; }
    const stats = State.snapshot(storage);
    for (const name of ["geo", "quest", "model", "forge"]) {
      $(name + "-count").textContent = stats[name] === null ? "!" : String(stats[name]);
      $(name + "-count").title = stats[name] === null ?
        "Локальный файл не удалось прочитать; скачайте резервную копию из редактора." : "Локальные записи";
    }
    $("last-status").textContent = Object.values(stats).some(v=>v===null) ? "ЛОКАЛЬНЫЕ ДАННЫЕ / ПРОВЕРЬТЕ ХРАНИЛИЩЕ" : "ЛОКАЛЬНЫЕ ДАННЫЕ / ТЕКУЩИЙ БРАУЗЕР";
  };

  function injectEmbeddedStyle(frame, mode) {
    try {
      const doc = frame.contentDocument;
      if (!doc?.head || embeddedDocuments.has(doc)) return;
      const styles = doc.createElement("style");
      styles.dataset.chernozeryeStudio = "embedded";
      styles.textContent = mode === "geo" ?
        "html,body{height:100%!important;}body{overflow:hidden!important}.workspace{height:100vh!important;min-height:0!important}.sidebar{max-height:100vh!important}" :
        ".topbar{display:none!important}.statusbar,.footer{display:none!important}.studio,.app{height:100vh!important;min-height:0!important}.workspace{min-height:0!important}";
      doc.head.appendChild(styles);
      embeddedDocuments.add(doc);
      // Route links between editors to the Studio navigation rather than
      // replacing the contents of this one iframe.
      doc.addEventListener("click", (event) => {
        const link = event.target.closest?.("a[href]");
        if (!link || event.defaultPrevented || event.ctrlKey || event.metaKey ||
            event.shiftKey || event.altKey || link.target === "_blank") return;
        let url;
        try { url = new URL(link.href, frame.contentWindow.location.href); } catch { return; }
        if (url.origin !== window.location.origin) return;
        const next = State.routeForUrl(url.href, window.location.href);
        if (!next) return;
        event.preventDefault();
        show(next, true, url);
      }, {capture: true});
      doc.addEventListener("keydown", (event) => {
        if ((event.ctrlKey || event.metaKey) && !event.altKey && event.code === "KeyB") {
          event.preventDefault(); event.stopImmediatePropagation(); setRailCollapsed(!railCollapsed); return;
        }
        const next = State.shortcut(event);
        if (next) { event.preventDefault(); event.stopImmediatePropagation(); show(next); }
      }, {capture: true});
    } catch (error) {
      console.warn("Studio frame embedding failed", mode, error);
    }
  }
  function focusFrame(id) {
    const entry = cached.get(id);
    if (!entry) return;
    entry.frame.hidden = false;
    // Leaflet and WebGL observers can need a fresh resize after being hidden.
    window.requestAnimationFrame(() => {
      try {
        entry.frame.contentWindow.dispatchEvent(new Event("resize"));
        if (id === "quest") entry.frame.contentWindow.QuestGeoOverlayRefresh?.();
        if (id === "arms") entry.frame.contentWindow.refreshArmLibrary?.();
      }
      catch { /* the standalone editors still work */ }
    });
  }
  function createFrame(id, initialUrl = null) {
    if (cached.has(id)) return cached.get(id);
    const config = MODES[id];
    const frame = document.createElement("iframe");
    frame.className = "editor-frame";
    frame.title = "Рабочая область " + id.toUpperCase() + " LAB";
    frame.loading = "eager";
    frame.referrerPolicy = "strict-origin-when-cross-origin";
    frame.dataset.tool = id;
    const entry = { frame, ready:false };
    cached.set(id, entry);
    frame.addEventListener("load", () => {
      entry.ready = true;
      injectEmbeddedStyle(frame, id);
      if (id === active) {
        $("frame-status").textContent = id.toUpperCase() + " / ОТКРЫТ";
        focusFrame(id);
      }
      refreshStats();
    });
    frame.addEventListener("error", () => {
      if (id === active) $("frame-status").textContent = "ОШИБКА ЗАГРУЗКИ · ОТКРОЙТЕ ОТДЕЛЬНО";
    });
    frame.src = initialUrl || config.file;
    $("editors").appendChild(frame);
    return entry;
  }
  function show(next, setHash = true, editorUrl = null) {
    const id = State.toolId(next);
    if (active === id && !editorUrl) return;
    active = id;
    const config = MODES[id];
    $("section-kicker").textContent = config.kicker;
    $("section-title").textContent = config.name;
    for (const b of document.querySelectorAll("[data-target]")) {
      const selected = b.dataset.target === id;
      b.classList.toggle("active", selected);
      b.setAttribute("aria-current", selected ? "page" : "false");
    }
    const isHome = id === "home";
    $("overview").hidden = !isHome;
    $("editors").hidden = isHome;
    $("reload-editor").hidden = isHome;
    $("external-editor").hidden = isHome;
    $("frame-status").textContent = isHome ? "ЦЕНТР УПРАВЛЕНИЯ" : id.toUpperCase() + " / ЗАГРУЗКА";
    if (!isHome) $("external-editor").href = config.url;
    for (const [key, value] of cached.entries()) value.frame.hidden = key !== id;
    if (!isHome) {
      const existing = cached.get(id);
      const isQuestModel = !!(editorUrl && id === "quest" && editorUrl.searchParams.has("model"));
      const initial = isQuestModel && !existing ? new URL(editorUrl.href) : null;
      if(initial)initial.searchParams.set("studio","1");
      const entry = createFrame(id,initial?.href);
      if (editorUrl && (id === "arms" || isQuestModel)) {
        $("external-editor").href = editorUrl.href;
        editorUrl.searchParams.set("studio", "1");
        if(isQuestModel && existing && entry.ready && typeof entry.frame.contentWindow.QuestOpenPlacements==="function") {
          entry.frame.contentWindow.QuestOpenPlacements(editorUrl.searchParams.get("model"));
        }else if (entry.frame.src !== editorUrl.href) {
          entry.ready = false;
          entry.frame.src = editorUrl.href;
        }
      }
      if (entry.ready) {
        $("frame-status").textContent = id.toUpperCase() + " / ОТКРЫТ";
        focusFrame(id);
      }
    }
    if (setHash && window.location.hash !== "#" + id) {
      history.pushState(null, "", "#" + id);
    }
    refreshStats();
    if(isHome && dashboardTabs.some(t=>t.dataset.dashboard==="assets"&&t.getAttribute?.("aria-pressed")==="true"))void window.ChernoAssetCatalogRefresh?.();
  }
  for (const b of document.querySelectorAll("[data-target]")) {
    b.addEventListener("click", (event) => { event.preventDefault(); show(b.dataset.target); });
  }
  $("rail-toggle").addEventListener("click", () => setRailCollapsed(!railCollapsed));
  document.querySelector(".rail").addEventListener("transitionend", (event) => {
    if (event.propertyName === "width") notifyEditorResize();
  });
  const dashboardTabs = [...document.querySelectorAll("[data-dashboard]")];
  const dashboardPanels = [...document.querySelectorAll("[data-dashboard-panel]")];
  for (const button of dashboardTabs) {
    button.addEventListener("click", () => {
      const id = button.dataset.dashboard;
      for (const tab of dashboardTabs) {
        const selected = tab.dataset.dashboard === id;
        tab.classList.toggle("active", selected);
        tab.setAttribute("aria-pressed", String(selected));
      }
      for (const panel of dashboardPanels) panel.hidden = panel.dataset.dashboardPanel !== id;
      if (id === "data") refreshStats();
      if (id === "assets") void window.ChernoAssetCatalogRefresh?.();
    });
  }
  $("reload-editor").addEventListener("click", () => {
    if (!active || active === "home") return;
    const entry = cached.get(active);
    if (!entry) return;
    $("frame-status").textContent = active.toUpperCase() + " / ПЕРЕЗАГРУЗКА";
    entry.ready = false;
    entry.frame.contentWindow.location.reload();
  });
  window.addEventListener("hashchange", () => show(State.toolId(location.hash), false));
  window.addEventListener("popstate", () => show(State.toolId(location.hash), false));
  window.addEventListener("storage", (evt) => {
    if (!evt.key || Object.values(State.KEYS).includes(evt.key)) refreshStats();
  });
  window.addEventListener("focus", refreshStats);
  window.addEventListener("keydown", (evt) => {
    if ((evt.ctrlKey || evt.metaKey) && !evt.altKey && evt.code === "KeyB") {
      evt.preventDefault();
      setRailCollapsed(!railCollapsed);
      return;
    }
    const id = State.shortcut(evt);
    if (id) { evt.preventDefault(); show(id); }
  });
  setRailCollapsed(railCollapsed);
  show(State.toolId(location.hash), false);
  console.info("CHERNOZERYE_STUDIO_READY: workspace=local navigation="+State.TOOLS.length);
})();
