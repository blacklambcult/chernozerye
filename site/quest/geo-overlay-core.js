/* Shared map layer adapter for Quest Lab. No new copy of the user's Geo Lab data. */
(function(root, factory) {
  const value = factory();
  if (typeof module === "object" && module.exports) module.exports = value;
  root.ChernoQuestGeo = value;
})(typeof globalThis !== "undefined" ? globalThis : this, function() {
  "use strict";
  const STORAGE_KEY = "chernozerye_manual_geojson_v2";
  const SOURCES = Object.freeze([
    { id:"overture", file:"overture.geojson", title:"Здания Overture", color:"#ee9973" },
    { id:"roads", file:"roads.geojson", title:"Дороги OSM", color:"#e7b467" },
    { id:"vegetation", file:"vegetation.geojson", title:"Лес и растительность OSM", color:"#6abf88" },
    { id:"water", file:"water.geojson", title:"Вода OSM", color:"#60b9dd" }
  ]);
  const MANUAL_STYLES = Object.freeze({
    road: { color:"#ffca7f", weight:4, opacity:0.96 },
    path: { color:"#f3dd99", weight:2.5, dashArray:"7,5" },
    water: { color:"#63d1f5", weight:2.3, fillOpacity:0.38 },
    forest: { color:"#67d69b", weight:2.3, fillOpacity:0.28 },
    plot: { color:"#d3b2ff", weight:1.9, dashArray:"5,4", fillOpacity:0.08 },
    object: { color:"#d2d5ce", weight:2.1, fillOpacity:0.2 },
    house: { color:"#ff9868", weight:2.4, fillOpacity:0.37 },
    shed: { color:"#e4b583", weight:2.2, fillOpacity:0.36 },
    sauna: { color:"#f47b8a", weight:2.2, fillOpacity:0.32 },
    car: { color:"#8ec7fa", weight:2.2, fillOpacity:0.43 }
  });
  function readManual(raw, geoCore) {
    if (raw === null || raw === "") return [];
    if (typeof raw !== "string") throw new Error("Geo Lab storage value is not a string");
    if (!geoCore || typeof geoCore.importCollection !== "function")
      throw new Error("Geo Lab validation module not loaded");
    return geoCore.importCollection(JSON.parse(raw));
  }
  function sourceCounts(data) {
    if (!data || data.type !== "FeatureCollection" || !Array.isArray(data.features))
      throw new Error("Incorrect GeoJSON FeatureCollection");
    return data.features.length;
  }
  function manualStyle(category) {
    return { color:"#afbcb5", weight:1.9, opacity:0.94, fillOpacity:0.2,
      ...(MANUAL_STYLES[category] || {}) };
  }
  function sourceStyle(id) {
    const colors = {
      overture: { color:"#d18a69", weight:1.15, fillColor:"#c28563", fillOpacity:0.13, opacity:0.83 },
      roads: { color:"#d3b17b", weight:2.15, opacity:0.82 },
      vegetation: { color:"#69b889", fillColor:"#5eb47b", fillOpacity:0.16, weight:1.4, opacity:0.8 },
      water: { color:"#59b8d7", fillColor:"#4c9cbf", fillOpacity:0.3, weight:1.65, opacity:0.88 }
    };
    if (!Object.hasOwn(colors, id)) throw new Error("Unknown map data source: "+id);
    return {...colors[id]};
  }

  // Persistent Geo Lab IDs become typed, deterministic Quest Lab targets.
  // Only user-authored Geo Lab geometry is linkable: basemap tiles do not
  // provide the stable, editable object IDs required by quests.
  function featurePoint(feature) {
    if (!feature || feature.type !== "Feature" || !feature.geometry) throw Error("Геообъект повреждён");
    const geometry=feature.geometry;
    if(geometry.type==="Point") {
      if(!Array.isArray(geometry.coordinates)||geometry.coordinates.length<2)throw Error("Повреждённая точка");
      const [lon,lat]=geometry.coordinates;
      if(!Number.isFinite(lon)||!Number.isFinite(lat))throw Error("Неверные координаты");
      return {lon,lat};
    }
    if(geometry.type==="LineString") {
      const points=geometry.coordinates;
      if(!Array.isArray(points)||points.length<2)throw Error("Повреждённая линия");
      const lengths=[];
      let total=0;
      for(let i=1;i<points.length;i++){
        const dx=points[i][0]-points[i-1][0],dy=points[i][1]-points[i-1][1];
        const len=Math.hypot(dx*Math.cos(points[i][1]*Math.PI/180),dy);
        total+=len;
        lengths.push(len);
      }
      let remaining=total/2;
      for(let i=0;i<lengths.length;i++) {
        if(remaining<=lengths[i]||i===lengths.length-1) {
          const t=lengths[i]>0?Math.max(0,Math.min(1,remaining/lengths[i])):0;
          return {lon:points[i][0]+t*(points[i+1][0]-points[i][0]),
            lat:points[i][1]+t*(points[i+1][1]-points[i][1])};
        }
        remaining-=lengths[i];
      }
    }
    if(geometry.type==="Polygon") {
      const pts=geometry.coordinates?.[0];
      if(!Array.isArray(pts)||pts.length<4)throw Error("Повреждённый полигон");
      // Area-weighted centroid of the exterior ring, no projection or backend.
      // If the polygon is degenerate, retain a stable mid-point fallback.
      // Shift local origin: naive cross-products at lon 55 / lat 54
      // lose precision for small building footprints.
      const origin=pts[0];
      let area2=0,cx=0,cy=0;
      for(let i=0;i<pts.length-1;i++){
        const x0=pts[i][0]-origin[0],y0=pts[i][1]-origin[1];
        const x1=pts[i+1][0]-origin[0],y1=pts[i+1][1]-origin[1];
        const cross=x0*y1-x1*y0;
        area2+=cross;cx+=(x0+x1)*cross;cy+=(y0+y1)*cross;
      }
      if(Math.abs(area2)>1e-18){
        const lon=origin[0]+cx/(3*area2),lat=origin[1]+cy/(3*area2);
        if(Number.isFinite(lon)&&Number.isFinite(lat))return {lon,lat};
      }
      const count=pts.length-1;
      return {lon:pts.slice(0,-1).reduce((sum,p)=>sum+p[0],0)/count,
        lat:pts.slice(0,-1).reduce((sum,p)=>sum+p[1],0)/count};
    }
    throw Error("Неподдерживаемый тип геометрии");
  }
  function objectIndex(features) {
    if(!Array.isArray(features)||features.length>10000)throw Error("Неверный набор Geo Lab объектов");
    const index=new Map();
    for(const feature of features) {
      const objectId=String(feature.id||feature.properties?.id||"");
      if(!objectId||objectId.length>120)continue; // Quest Lab ID format limit.
      if(index.has(objectId))throw Error("Повторный ID геообъекта");
      const position=featurePoint(feature);
      const category=String(feature.properties?.category||"object");
      const name=String(feature.properties?.name||"").trim();
      index.set(objectId,Object.freeze({id:objectId,category,name,position,
        feature}));
    }
    return index;
  }
  function objectLabel(entry) {
    const known={house:"Дом",forest:"Лес",water:"Водоём",road:"Дорога",
      path:"Тропинка",plot:"Участок",shed:"Сарай",sauna:"Баня",
      car:"Машина",object:"Объект"};
    return (known[entry.category]||"Объект")+(entry.name?" · "+entry.name:"");
  }
  function searchObjects(index,term,limit=8) {
    if(!(index instanceof Map))throw Error("Требуется индекс объектов");
    const query=String(term||"").trim().toLocaleLowerCase("ru");
    if(!query)return [];
    const max=Math.max(1,Math.min(30,Math.floor(limit)));
    const result=[];
    for(const entry of index.values()) {
      const hay=(entry.id+" "+entry.name+" "+entry.category+" "+objectLabel(entry))
        .toLocaleLowerCase("ru");
      if(hay.includes(query))result.push(entry);
      if(result.length>=max)break;
    }
    return result;
  }
  function resolveBinding(step,index,questCore) {
    if(!step||!step.objectId)return {status:"empty",entry:null,point:null};
    if(!(index instanceof Map))throw Error("Требуется индекс объектов");
    const entry=index.get(step.objectId);
    if(!entry)return {status:"missing",entry:null,point:null};
    const point=questCore.point(entry.position);
    const unchanged=step.target&&step.target.lon===point.lon&&step.target.lat===point.lat;
    return {status:unchanged?"linked":"moved",entry,point};
  }
  function bindStep(step,objectId,index,questCore) {
    if(!step||step.type==="message")throw Error("К сообщению нельзя привязать геообъект");
    const entry=index.get(objectId);
    if(!entry)throw Error("Объект Geo Lab не найден");
    const updated={...step,objectId:entry.id,target:questCore.point(entry.position)};
    return questCore.normalizeStep(updated);
  }

  function overlayStatus({manualCount=0, ready=0, failed=0, manualError=""} = {}) {
    const suffix = [manualError, failed ? "часть базовых слоёв недоступна" : ""].filter(Boolean);
    return { text: "GEO LAB / " + manualCount + " МОИХ · " + ready + "/" + SOURCES.length + " БАЗОВЫХ" +
      (suffix.length ? " · " + suffix.join(" · ") : ""), warning: suffix.length > 0 };
  }
  return Object.freeze({ overlayStatus, STORAGE_KEY, SOURCES, MANUAL_STYLES,
    readManual, sourceCounts, sourceStyle, manualStyle,
    featurePoint, objectIndex, objectLabel, searchObjects, resolveBinding, bindStep });
});
