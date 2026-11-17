/* CHERNOZERYE / GEO LAB 1.9
 * Read-only geographic comparison. Coordinates are WGS84 converted at build time
 * from the original EPSG:32640 project-relative metres. Never scrape imagery.
 */
(() => {
  "use strict";

  const byId = (id) => document.getElementById(id);
  const status = byId("map-status");
  const fatal = byId("fatal");
  const counts = {
    overture: byId("count-overture"),
    roads: byId("count-roads"),
    osm: byId("count-osm"),
    nature: byId("count-nature")
  };
  const state = {
    view: "a",
    base: "imagery",
    map: null,
    views: {},
    layers: {},
    selected: null,
    opacity: 0.25,
    sourceData: {}
  };

  function report(message, warning = false) {
    status.textContent = message;
    status.classList.toggle("is-warning", warning);
  }

  function escapeText(text) {
    return String(text ?? "").replace(/[&<>"']/g, (char) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[char]));
  }

  if (typeof L === "undefined") {
    fatal.hidden = false;
    report("Leaflet недоступен. Проверь интернет и обнови страницу.", true);
    return;
  }

  const map = L.map("map", {
    zoomControl: false,
    preferCanvas: true,
    minZoom: 11,
    maxZoom: 19,
    zoomSnap: 0.25,
    attributionControl: true
  });
  state.map = map;
  map.setView([54.6728972, 55.8528151], 15);
  L.control.zoom({ position: "bottomright" }).addTo(map);
  L.control.scale({ position: "bottomright", metric: true, imperial: false }).addTo(map);
  ["study", "nature", "road", "osm", "overture"].forEach((name, index) => {
    map.createPane(name);
    map.getPane(name).style.zIndex = String(390 + index * 12);
  });

  // The Esri Leaflet layer provides dynamic regional imagery attribution.
  // A direct tile fallback is only for failure to load the plugin.
  const esriUrl = "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer";
  const satellite = (L.esri && typeof L.esri.tiledMapLayer === "function")
    ? L.esri.tiledMapLayer({
        url: esriUrl, maxZoom: 19,
        attribution: "Imagery © Esri, Maxar, Earthstar Geographics, GIS User Community"
      })
    : L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
        maxZoom: 19,
        attribution: "Imagery © Esri, Maxar, Earthstar Geographics, GIS User Community"
      });

  const streets = L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors'
  });
  satellite.addTo(map);

  let imageryErrors = 0;
  satellite.on("tileerror", () => {
    imageryErrors++;
    if (imageryErrors === 6 && state.base === "imagery") {
      switchBase("street");
      report("Спутниковые тайлы не загрузились — переключил на схему OSM. Попробуй «Спутник» позже.", true);
    }
  });

  function updateCoordinates() {
    const center = map.getCenter();
    byId("map-coords").textContent = center.lat.toFixed(6) + ", " + center.lng.toFixed(6);
  }
  map.on("moveend", updateCoordinates);
  updateCoordinates();

  function switchBase(kind) {
    const imagery = kind === "imagery";
    map.removeLayer(imagery ? streets : satellite);
    if (!map.hasLayer(imagery ? satellite : streets)) {
      (imagery ? satellite : streets).addTo(map);
    }
    state.base = kind;
    for (const name of ["imagery", "street"]) {
      const button = byId("base-" + name);
      button.classList.toggle("active", name === kind);
      button.setAttribute("aria-pressed", String(name === kind));
    }
  }
  byId("base-imagery").addEventListener("click", () => {
    imageryErrors = 0;
    switchBase("imagery");
  });
  byId("base-street").addEventListener("click", () => switchBase("street"));

  const overlayOptions = { renderer: L.canvas({ padding: 0.3 }) };
  function geolayer(data, options = {}) {
    return L.geoJSON(data, Object.assign({}, overlayOptions, options));
  }

  function showLayer(name, show) {
    const layer = state.layers[name];
    if (!layer) return;
    if (show && !map.hasLayer(layer)) layer.addTo(map);
    if (!show && map.hasLayer(layer)) map.removeLayer(layer);
  }

  function featureCenter(feature) {
    const ring = feature.geometry?.coordinates?.[0];
    if (!ring || ring.length < 3) return null;
    let lat = 0, lon = 0, count = 0;
    for (let i = 0; i < ring.length - 1; i++) {
      lon += Number(ring[i][0]);
      lat += Number(ring[i][1]);
      count++;
    }
    return count ? L.latLng(lat / count, lon / count) : null;
  }

  let activeHighlight = null;
  function selectBuilding(feature, event) {
    const p = feature.properties || {};
    const center = featureCenter(feature);
    if (!center) return;
    const area = Number(p.area_m2);
    const areaText = Number.isFinite(area) ? area.toLocaleString("ru-RU", { maximumFractionDigits: 1 }) + " м²" : "не указана";
    const heightText = Number.isFinite(Number(p.height_m)) && p.height_m != null
      ? String(p.height_m) + " м (из источника)" : "не указана";
    const id = String(p.id || feature.id || "без идентификатора");
    const panel = byId("selection");

    panel.replaceChildren();
    const eyebrow = document.createElement("span");
    eyebrow.className = "eyebrow";
    eyebrow.textContent = "ВЫБРАННОЕ ЗДАНИЕ · OVERTURE";
    const description = document.createElement("p");
    const text1 = document.createElement("strong");
    text1.textContent = "Площадь контура: " + areaText;
    const text2 = document.createElement("span");
    text2.textContent = "\nВысота: " + heightText + "\nКоординаты: " +
      center.lat.toFixed(6) + ", " + center.lng.toFixed(6);
    text2.style.whiteSpace = "pre-line";
    description.append(text1, document.createElement("br"), text2);
    const note = document.createElement("p");
    note.textContent = "Это контур-кандидат, не подтверждённый адрес или жилой дом.";
    note.style.color = "#91a4a5";
    const copy = document.createElement("button");
    copy.type = "button";
    copy.className = "copy-button";
    copy.textContent = "Скопировать координаты";
    copy.addEventListener("click", () => {
      const value = center.lat.toFixed(7) + ", " + center.lng.toFixed(7);
      if (navigator.clipboard?.writeText) {
        navigator.clipboard.writeText(value).then(() => {
          copy.textContent = "Координаты скопированы";
        }).catch(() => {
          copy.textContent = value;
        });
      } else copy.textContent = value;
    });
    panel.append(eyebrow, description, note, copy);

    const popup = '<strong>Контур Overture</strong><br>Площадь: ' + escapeText(areaText) +
      '<br>Высота: ' + escapeText(heightText) +
      '<br><small>ID: ' + escapeText(id) + '</small>' +
      '<br><small>Не подтверждено на местности</small>';
    L.popup({ maxWidth: 285, autoPan: true }).setLatLng(event.latlng).setContent(popup).openOn(map);

    if (activeHighlight) map.removeLayer(activeHighlight);
    activeHighlight = L.geoJSON(feature, {
      pane: "overture", interactive: false, renderer: overlayOptions.renderer,
      style: { color: "#fff4c2", weight: 3.1, fill: false }
    }).addTo(map);
    state.selected = id;
  }

  function viewCount(bounds) {
    const features = state.sourceData.overture?.features || [];
    let count = 0;
    for (const feature of features) {
      const c = featureCenter(feature);
      if (c && bounds.contains(c)) count++;
    }
    return count;
  }

  function selectView(name) {
    state.view = name;
    document.querySelectorAll("[data-view]").forEach((element) => {
      element.classList.toggle("is-active", element.dataset.view === name);
    });
    const labels = { all: "ВСЯ ТЕРРИТОРИЯ", a: "СЕКТОР A", "a-street": "КВАРТАЛ A" };
    byId("active-area-title").textContent = labels[name] || "ИССЛЕДОВАНИЕ";
    if (state.views[name]) {
      map.fitBounds(state.views[name].getBounds(), { padding: [34, 34], animate: false, maxZoom: 19 });
      if (state.layers.study) state.layers.study.setStyle((feature) => ({
        color: feature.properties?.id === name ? "#ffc180" : "#b9ced0",
        weight: feature.properties?.id === name ? 2.5 : 1,
        opacity: feature.properties?.id === name ? 0.95 : 0.35,
        fill: false, dashArray: feature.properties?.id === name ? null : "7,8"
      }));
      report("Контуры Overture в этом окне: " + viewCount(state.views[name].getBounds()) +
        " · сравни здания и дороги со спутником.");
    }
  }
  document.querySelectorAll("[data-view]").forEach((element) => {
    element.addEventListener("click", () => selectView(element.dataset.view));
  });

  function updateOpacity() {
    const value = Number(byId("fill-opacity").value) / 100;
    state.opacity = value;
    byId("opacity-value").textContent = String(Math.round(value * 100)) + "%";
    if (state.layers.overture) {
      state.layers.overture.setStyle({
        color: "#eab0dc", weight: 1.25,
        fillColor: "#f2a9d7", fillOpacity: value
      });
    }
  }
  byId("fill-opacity").addEventListener("input", updateOpacity);

  const toggles = [
    ["layer-overture", "overture"],
    ["layer-osm-roads", "roads"],
    ["layer-osm-buildings", "osm"],
    ["layer-nature", "nature"],
    ["layer-study-area", "study"]
  ];
  toggles.forEach(([inputId, layerId]) => {
    byId(inputId).addEventListener("change", (event) => {
      showLayer(layerId, event.target.checked);
    });
  });

  async function loadGeo(filename) {
    const response = await fetch("./data/" + filename, { cache: "no-store" });
    if (!response.ok) throw new Error(filename + ": HTTP " + response.status);
    return response.json();
  }

  async function loadAll() {
    try {
      const [overture, roads, osm, vegetation, water, areas, metadata] = await Promise.all([
        loadGeo("overture.geojson"),
        loadGeo("roads.geojson"),
        loadGeo("osm-buildings.geojson"),
        loadGeo("vegetation.geojson"),
        loadGeo("water.geojson"),
        loadGeo("study-areas.geojson"),
        loadGeo("meta.json")
      ]);
      state.sourceData = { overture, roads, osm, vegetation, water, areas, metadata };

      state.layers.overture = geolayer(overture, {
        pane: "overture",
        style: { color: "#eab0dc", weight: 1.25, fillColor: "#f2a9d7", fillOpacity: state.opacity },
        onEachFeature: (feature, layer) => {
          layer.on("click", (event) => selectBuilding(feature, event));
        }
      });
      state.layers.roads = geolayer(roads, {
        pane: "road",
        interactive: false,
        style: (feature) => ({
          color: feature.properties?.highway === "trunk" || feature.properties?.highway === "primary"
            ? "#ffca83" : "#efbe72",
          weight: feature.properties?.highway === "trunk" ? 3.3 : 2.1,
          opacity: 0.9
        })
      });
      state.layers.osm = geolayer(osm, {
        pane: "osm", interactive: false,
        style: { color: "#77f0e4", weight: 1.8, fillColor: "#4dbeb8", fillOpacity: 0.1 }
      });
      const woods = geolayer(vegetation, {
        pane: "nature", interactive: false,
        style: { color: "#6fb486", weight: 1.3, fillColor: "#65a479", fillOpacity: 0.19 }
      });
      const waterways = geolayer(water, {
        pane: "nature", interactive: false,
        style: { color: "#7cc7e9", weight: 3, fillColor: "#61afd9", fillOpacity: 0.18 }
      });
      state.layers.nature = L.featureGroup([woods, waterways]);
      state.layers.study = geolayer(areas, {
        pane: "study", interactive: false,
        style: { color: "#ffc180", weight: 1, opacity: 0.5, fill: false, dashArray: "6,7" }
      });

      for (const [input, layerName] of toggles) {
        showLayer(layerName, byId(input).checked);
      }

      const areaFeatures = areas.features || [];
      for (const feature of areaFeatures) {
        state.views[feature.properties.id] = L.geoJSON(feature);
      }

      counts.overture.textContent = (overture.features || []).length.toLocaleString("ru-RU");
      counts.roads.textContent = (roads.features || []).length.toLocaleString("ru-RU");
      counts.osm.textContent = (osm.features || []).length.toLocaleString("ru-RU");
      counts.nature.textContent = ((vegetation.features || []).length + (water.features || []).length).toLocaleString("ru-RU");

      if (!state.views.a || !state.views.all || !state.views["a-street"]) {
        throw new Error("Нет границ исследуемых секторов");
      }
      selectView("a");
      updateOpacity();
    } catch (error) {
      console.error("GEO LAB: cannot load geographic layers", error);
      report("Не удалось загрузить географические слои: " + error.message + ". Спутниковая карта остаётся доступна.", true);
    }
  }

  loadAll();
})();
