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
    weapon: {kicker:"PROCEDURAL ARMORY / 05", name:"ГЕНЕРАТОР ОРУЖИЯ · 8 КЛАССОВ", url:"../weapon-generator/", file:"../weapon-generator/?studio=1"}
  });
  const COLLAPSE_KEY = "chernozerye.studio.rail-collapsed.v1";
  const cached = new Map();
  let railCollapsed = false;
  function notifyEditorResize() {
    const current = cached.get(active);
    if (!current) return;
    requestAnimationFrame(() => {
      try {
        current.frame.contentWindow.dispatchEvent(new Event("resize"));
        current.frame.contentWindow.QuestGeoOverlayRefresh?.();
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
    const stats = State.snapshot(localStorage);
    for (const name of ["geo", "quest", "model", "forge"]) {
      $(name + "-count").textContent = stats[name] === null ? "!" : String(stats[name]);
      $(name + "-count").title = stats[name] === null ?
        "Локальный файл не удалось прочитать; скачайте резервную копию из редактора." : "Локальные записи";
    }
    $("last-status").textContent = "СЕССИЯ / АВТОСОХРАНЕНИЕ В БРАУЗЕРЕ";
  };

  function injectEmbeddedStyle(frame, mode) {
    try {
      const doc = frame.contentDocument;
      if (!doc?.head || frame.dataset.embeddedReady === "1") return;
      const styles = doc.createElement("style");
      styles.dataset.chernozeryeStudio = "embedded";
      styles.textContent = mode === "geo" ?
        "html,body{height:100%!important;}body{overflow:hidden!important}.workspace{height:100vh!important;min-height:0!important}.sidebar{max-height:100vh!important}" :
        ".topbar{display:none!important}.statusbar,.footer{display:none!important}.studio,.app{height:100vh!important;min-height:0!important}.workspace{min-height:0!important}";
      doc.head.appendChild(styles);
      frame.dataset.embeddedReady = "1";
      // Route links between editors to the Studio navigation rather than
      // replacing the contents of this one iframe.
      doc.addEventListener("click", (event) => {
        const link = event.target.closest?.("a[href]");
        if (!link || event.defaultPrevented || event.ctrlKey || event.metaKey ||
            event.shiftKey || event.altKey || link.target === "_blank") return;
        let url;
        try { url = new URL(link.href, frame.contentWindow.location.href); } catch { return; }
        if (url.origin !== window.location.origin) return;
        const match = url.pathname.match(/\/chernozerye\/(map|quest|model|forge|weapon-generator|studio)\/?$/);
        if (!match) return;
        event.preventDefault();
        show(match[1] === "map" ? "geo" : match[1] === "studio" ? "home" :
          match[1] === "weapon-generator" ? "weapon" : match[1]);
      }, {capture: true});
      doc.addEventListener("keydown", (event) => {
        if (!event.altKey || event.ctrlKey || event.metaKey) return;
        const next = { Digit0:"home", Digit1:"geo", Digit2:"quest", Digit3:"model", Digit4:"forge", Digit5:"weapon" }[event.code];
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
      }
      catch { /* the standalone editors still work */ }
    });
  }
  function createFrame(id) {
    if (cached.has(id)) return cached.get(id);
    const config = MODES[id];
    const frame = document.createElement("iframe");
    frame.className = "editor-frame";
    frame.title = "Рабочая область " + id.toUpperCase() + " LAB";
    frame.loading = "eager";
    frame.referrerPolicy = "strict-origin-when-cross-origin";
    frame.dataset.tool = id;
    frame.src = config.file;
    $("editors").appendChild(frame);
    const entry = { frame, ready:false };
    cached.set(id, entry);
    frame.addEventListener("load", () => {
      entry.ready = true;
      injectEmbeddedStyle(frame, id);
      if (id === active) {
        $("frame-status").textContent = id.toUpperCase() + " LAB / ГОТОВ";
        focusFrame(id);
      }
      refreshStats();
    });
    frame.addEventListener("error", () => {
      if (id === active) $("frame-status").textContent = "ОШИБКА ЗАГРУЗКИ · ОТКРОЙТЕ ОТДЕЛЬНО";
    });
    return entry;
  }
  function show(next, setHash = true) {
    const id = State.toolId(next);
    active = id;
    const config = MODES[id];
    $("section-kicker").textContent = config.kicker;
    $("section-title").textContent = config.name;
    $("rail-toggle").addEventListener("click", () => setRailCollapsed(!railCollapsed));
  document.querySelector(".rail").addEventListener("transitionend", (event) => {
    if (event.propertyName === "width") notifyEditorResize();
  });
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
    $("frame-status").textContent = isHome ? "ВСЁ ГОТОВО" : id.toUpperCase() + " LAB / ЗАГРУЗКА";
    if (!isHome) $("external-editor").href = config.url;
    for (const [key, value] of cached.entries()) value.frame.hidden = key !== id;
    if (!isHome) {
      const entry = createFrame(id);
      if (entry.ready) {
        $("frame-status").textContent = id.toUpperCase() + " LAB / ГОТОВ";
        focusFrame(id);
      }
    }
    if (setHash && window.location.hash !== "#" + id) {
      history.pushState(null, "", "#" + id);
    }
    refreshStats();
  }
  for (const b of document.querySelectorAll("[data-target]")) {
    b.addEventListener("click", () => show(b.dataset.target));
  }
  for (const b of document.querySelectorAll("[data-open]")) {
    b.addEventListener("click", () => show(b.dataset.open));
  }
  $("reload-editor").addEventListener("click", () => {
    if (!active || active === "home") return;
    const entry = cached.get(active);
    if (!entry) return;
    $("frame-status").textContent = active.toUpperCase() + " LAB / ПЕРЕЗАГРУЗКА";
    entry.ready = false;
    entry.frame.dataset.embeddedReady = "0";
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
    if (!evt.altKey || evt.ctrlKey || evt.metaKey) return;
    const id = {Digit0:"home",Digit1:"geo",Digit2:"quest",Digit3:"model",Digit4:"forge",Digit5:"weapon"}[evt.code];
    if (id) { evt.preventDefault(); show(id); }
  });
  setRailCollapsed(railCollapsed);
  refreshStats();
  show(State.toolId(location.hash), false);
  console.info("CHERNOZERYE_STUDIO_READY: geo=true quest=true model=true forge=true weapon=true workspace=local");
})();
