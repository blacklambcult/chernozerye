/* CHERNOZERYE Geo Lab 2.0 — independent serializable manual survey format.
 * Pure helpers used by browser UI and Node CI. WGS84 [longitude, latitude].
 */
(function (root, factory) {
  const core = factory();
  if (typeof module === "object" && module.exports) module.exports = core;
  else root.GeoLabEditorCore = core;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const TYPES = Object.freeze({
    road:   { label: "Дорога", geometry: "LineString", color: "#efb568" },
    path:   { label: "Тропинка", geometry: "LineString", color: "#e6d786" },
    water:  { label: "Водоём", geometry: "Polygon", color: "#50bdde" },
    forest: { label: "Лес", geometry: "Polygon", color: "#60b887" },
    plot:   { label: "Участок", geometry: "Polygon", color: "#c3a5f1" },
    object: { label: "Другой объект", geometry: "Polygon", color: "#c1c8bf" },
    house:  { label: "Дом", geometry: "Polygon", color: "#ef986e" },
    shed:   { label: "Сарай", geometry: "Polygon", color: "#c6a174" },
    sauna:  { label: "Баня", geometry: "Polygon", color: "#e36f7b" },
    car:    { label: "Машина", geometry: "Polygon", allowPoint: true, color: "#79b9eb" }
  });
  const LIMITS = Object.freeze({ west: 55.7, east: 56.05, south: 54.55, north: 54.85 });

  function validPosition(pos) {
    return Array.isArray(pos) && pos.length >= 2 &&
      Number.isFinite(pos[0]) && Number.isFinite(pos[1]) &&
      pos[0] >= LIMITS.west && pos[0] <= LIMITS.east &&
      pos[1] >= LIMITS.south && pos[1] <= LIMITS.north;
  }
  function same(a, b) {
    return a[0] === b[0] && a[1] === b[1];
  }
  function cleanPositions(list) {
    if (!Array.isArray(list) || list.length > 5000) return null;
    const result = [];
    for (const point of list) {
      if (!validPosition(point)) return null;
      const p = [Number(point[0]), Number(point[1])];
      if (!result.length || !same(result[result.length - 1], p)) result.push(p);
    }
    return result;
  }
  function normalizeGeometry(geometry, category) {
    const spec = TYPES[category];
    if (!spec || !geometry || typeof geometry !== "object") return null;
    if (geometry.type === "Point") {
      if (!spec.allowPoint || !validPosition(geometry.coordinates)) return null;
      return { type: "Point", coordinates: geometry.coordinates.slice(0, 2) };
    }
    if (geometry.type !== spec.geometry) return null;
    if (geometry.type === "LineString") {
      const pts = cleanPositions(geometry.coordinates);
      if (!pts || pts.length < 2) return null;
      return { type: "LineString", coordinates: pts };
    }
    if (geometry.type === "Polygon") {
      if (!Array.isArray(geometry.coordinates) || !geometry.coordinates.length) return null;
      let pts = cleanPositions(geometry.coordinates[0]);
      if (!pts) return null;
      if (pts.length > 1 && same(pts[0], pts[pts.length - 1])) pts.pop();
      const unique = new Set(pts.map((p) => p.join(",")));
      if (pts.length < 3 || unique.size < 3) return null;
      pts.push(pts[0].slice());
      return { type: "Polygon", coordinates: [pts] };
    }
    return null;
  }

  // One validated per-feature recipe, stored with the existing permanent GeoJSON ID.
  const APPEARANCE_TYPES=Object.freeze({house:["building","izba"],shed:["building","saray"],sauna:["building","banya"],forest:["nature","tree"],water:["nature","water"]});
  function appearanceType(category){return APPEARANCE_TYPES[category]||null;}
  function normalizeAppearance(value,category){
    const spec=appearanceType(category);
    if(!spec||!value||value.version!==1||value.generator!==spec[0]||value.type!==spec[1])return null;
    const p=value.parameters;
    if(!p||typeof p!=="object"||Array.isArray(p))return null;
    const ranges=spec[1]==="izba"?{floors:[1,2],walls:[0,4],roof:[0,4],window:[0,4],door:[0,4]}:
      spec[1]==="saray"?{walls:[0,2],roof:[0,2],door:[0,2]}:
      spec[1]==="banya"?{walls:[0,2],roof:[0,2],door:[0,1]}:
      spec[1]==="tree"?{species:[0,8],height:[0,2],canopy:[0,2],seed:[0,4]}:
      {tile:[0,10],rot:[0,3],depth:[0,2],seed:[0,4]};
    const parameters={};
    for(const [key,[min,max]] of Object.entries(ranges)){
      if(!Number.isInteger(p[key])||p[key]<min||p[key]>max)return null;
      parameters[key]=p[key];
    }
    const result={version:1,generator:spec[0],type:spec[1],parameters};
    if(spec[0]==="building"){
      const conditions={};
      for(const key of ["walls","roof","door","fence"]){
        const condition=value.conditions?.[key];
        if(!["normal","ruined","cultist"].includes(condition))return null;
        conditions[key]=condition;
      }
      if(!Number.isInteger(value.conditions?.window)||value.conditions.window<0||value.conditions.window>4)return null;
      conditions.window=value.conditions.window;result.conditions=conditions;
    }else{
      if(!["n","d","c"].includes(value.environment))return null;
      result.environment=value.environment;
    }
    return result;
  }
  // Delta transform of source geometry around its vertex centroid, clockwise degrees.
  // Local tangent-plane approximation for the small world; normalization bounds still apply.
  function transformGeometry(geometry,category,{east=0,north=0,rotation=0,scale=1}={}){
    if(![east,north,rotation,scale].every(Number.isFinite)||Math.abs(east)>2000||Math.abs(north)>2000||Math.abs(rotation)>360||scale<0.1||scale>10)return null;
    const original=normalizeGeometry(geometry,category);if(!original)return null;
    const pts=original.type==="Point"?[original.coordinates]:original.type==="Polygon"?original.coordinates[0].slice(0,-1):original.coordinates;
    const lon=pts.reduce((sum,p)=>sum+p[0],0)/pts.length,lat=pts.reduce((sum,p)=>sum+p[1],0)/pts.length;
    const kx=111320*Math.cos(lat*Math.PI/180),ky=111132,a=rotation*Math.PI/180,c=Math.cos(a),s=Math.sin(a);
    const transformed=pts.map(p=>{const x=(p[0]-lon)*kx*scale,y=(p[1]-lat)*ky*scale;
      return [Number((lon+(x*c+y*s+east)/kx).toFixed(9)),Number((lat+(-x*s+y*c+north)/ky).toFixed(9))];});
    return normalizeGeometry({type:original.type,coordinates:original.type==="Point"?transformed[0]:original.type==="Polygon"?[transformed]:transformed},category);
  }

  function normalizeFeature(feature) {
    if (!feature || feature.type !== "Feature") return null;
    const properties = feature.properties || {};
    const category = String(properties.category || properties.kind || "");
    const geometry = normalizeGeometry(feature.geometry, category);
    if (!geometry) return null;
    const id = String(properties.id || feature.id || "").slice(0, 128);
    if (!id) return null;
    const appearance=properties.appearance==null?null:normalizeAppearance(properties.appearance,category);
    if(properties.appearance!=null&&!appearance)return null;
    return {
      type: "Feature",
      id,
      properties: {
        id,
        category,
        name: String(properties.name || "").slice(0, 120),
        notes: String(properties.notes || "").slice(0, 600),
        source: "user_manual",
        ...(appearance?{appearance}:{}),
        created_at: typeof properties.created_at === "string" ? properties.created_at.slice(0, 50) : "",
        updated_at: typeof properties.updated_at === "string" ? properties.updated_at.slice(0, 50) : ""
      },
      geometry
    };
  }

  function makeFeature(id, category, geometry, name = "", notes = "") {
    const now = new Date().toISOString();
    const feature = normalizeFeature({
      type: "Feature",
      id,
      properties: { id, category, name, notes, created_at: now, updated_at: now },
      geometry
    });
    if (!feature) throw new Error("Недопустимая геометрия: " + category);
    return feature;
  }

  function importCollection(value) {
    if (!value || value.type !== "FeatureCollection" || !Array.isArray(value.features)) {
      throw new Error("Ожидался файл GeoJSON FeatureCollection.");
    }
    if (value.features.length > 10000) throw new Error("Файл содержит слишком много объектов.");
    const result = [];
    const ids = new Set();
    for (const input of value.features) {
      const feature = normalizeFeature(input);
      if (!feature) throw new Error("Неизвестный тип, некорректные координаты или незамкнутый объект в GeoJSON.");
      if (ids.has(feature.id)) throw new Error("Повторяющийся идентификатор: " + feature.id);
      ids.add(feature.id);
      result.push(feature);
    }
    return result;
  }

  function mergeWorldFeatures(base,draft){
    const items=new Map();
    for(const feature of [...base,...draft]){
      const valid=normalizeFeature(feature);if(!valid)throw Error("Некорректный объект мира");
      items.set(valid.id,valid);
    }
    return [...items.values()];
  }

  function collectionFromFeatures(features) {
    return {
      type: "FeatureCollection",
      name: "CHERNOZERYE / manually mapped terrain",
      metadata: {
        schema: "chernozerye-geo-constructor-1",
        version: "2.0",
        crs: "EPSG:4326",
        coordinate_order: "[longitude, latitude]",
        origin: "user_manual",
        centre_wgs84: [55.8528151, 54.6728972],
        exported_at: new Date().toISOString(),
        note: "User-authored geography; review and transform to EPSG:32640 local metres before Godot import"
      },
      features: features.map((feature) => {
        const copy = normalizeFeature(feature);
        if (!copy) throw new Error("Не удаётся экспортировать повреждённый объект");
        return copy;
      })
    };
  }

  const rad = Math.PI / 180;
  function haversine(a, b) {
    const dLat = (b[1] - a[1]) * rad;
    const dLon = (b[0] - a[0]) * rad;
    const p1 = a[1] * rad, p2 = b[1] * rad;
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(p1) * Math.cos(p2) * Math.sin(dLon / 2) ** 2;
    return 12742000 * Math.asin(Math.min(1, Math.sqrt(h)));
  }
  function measure(feature) {
    const geom = feature && feature.geometry;
    if (!geom || geom.type === "Point") return { length_m: 0, area_m2: 0 };
    const pts = geom.type === "Polygon" ? geom.coordinates[0] : geom.coordinates;
    let length = 0;
    for (let i = 0; i < pts.length - 1; i++) length += haversine(pts[i], pts[i + 1]);
    let area = 0;
    if (geom.type === "Polygon") {
      // Local planar approximation for tiny 2×2 km field features.
      const lat = pts.reduce((a, p) => a + p[1], 0) / pts.length;
      const kx = 111320 * Math.cos(lat * rad), ky = 111132;
      for (let i = 0; i < pts.length - 1; i++) {
        area += (pts[i][0] * kx) * (pts[i + 1][1] * ky) -
          (pts[i + 1][0] * kx) * (pts[i][1] * ky);
      }
      area = Math.abs(area) / 2;
    }
    return { length_m: Math.round(length * 10) / 10, area_m2: Math.round(area * 10) / 10 };
  }

  return Object.freeze({ TYPES, LIMITS, normalizeGeometry, normalizeFeature, makeFeature,
    importCollection, collectionFromFeatures, measure, appearanceType, normalizeAppearance, transformGeometry, mergeWorldFeatures });
});
