/* HELLISH FORGE / VIRTUAL GAME ASSET SCHEMA 0.1
   Contains only visual parts, labels and local attachment transforms.
   Does not encode real-world operation or mechanisms.
*/
(function (root, factory) {
  const base = typeof module === "object" && module.exports
    ? require("../model/model-core.js") : root.ChernoModelCore;
  const api = factory(base);
  if (typeof module === "object" && module.exports) module.exports = api;
  root.ChernoHellishForge = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function(Model) {
  "use strict";
  if (!Model) throw new Error("Model Lab geometry schema is required");
  const FORMAT = "chernozerye.hellish-forge";
  const VERSION = 1;
  const STORAGE_KEY = "chernozerye.hellish-forge.v1";
  const GROUPS = Object.freeze({
    edged: {label:"ХОЛОДНОЕ", types:Object.freeze({knife:"Нож",sword:"Меч",saber:"Сабля",axe:"Топор",other:"Другое"})},
    blunt: {label:"ДРОБЯЩЕЕ",types:Object.freeze({club:"Дубинка",mace:"Булава",hammer:"Молот",other:"Другое"})},
    sidearm: {label:"ОДНОРУЧНОЕ",types:Object.freeze({revolver:"Револьвер",pistol:"Пистолет",smg:"Пистолет-пулемёт",other:"Другое"})},
    longarm: {label:"ДВУРУЧНОЕ",types:Object.freeze({shotgun:"Дробовик",rifle:"Винтовка",assault_rifle:"Автомат",machine_gun:"Пулемёт",launcher:"Гранатомёт",other:"Другое"})},
    special: {label:"УНИКАЛЬНОЕ",types:Object.freeze({crossbow:"Арбалет",bow:"Лук",throwing_spear:"Метательное копьё",artifact:"Артефакт",other:"Другое"})}
  });
  const ROLES = Object.freeze({
    body:"Основная геометрия",grip:"Рукоять",barrel:"Ствол (визуальный)",magazine:"Магазин (визуальный)",
    cylinder:"Барабан (визуальный)",stock:"Приклад (визуальный)",blade:"Лезвие (визуальное)",
    guard:"Защита / гарда",sight:"Прицел (визуальный)",detail:"Декор / прочее"
  });
  const ANCHORS = Object.freeze({
    grip_primary:"Основной хват / крепление к руке",
    grip_support:"Второй хват / вторая рука",
    forward:"Направление модели / -Z",
    magazine:"Метка магазина",
    cylinder:"Метка барабана",
    item_origin:"Опорная точка предмета"
  });
  const ANCHOR_COLORS = Object.freeze({
    grip_primary:"#ffc18a",grip_support:"#cba5ff",forward:"#78e1df",
    magazine:"#b0d28e",cylinder:"#e4a4b5",item_origin:"#ced5dc"
  });
  const finite = (v, low, high, context) => {
    if (typeof v !== "number" || !Number.isFinite(v) || v < low || v > high)
      throw new Error("Некорректная величина: "+context+" ("+low+"…"+high+")");
    return Math.round(v * 10000)/10000;
  };
  const vec = (value, low, high, context) => {
    if (!Array.isArray(value) || value.length !== 3)
      throw new Error(context+": ожидается вектор X/Y/Z");
    return value.map((v)=>finite(v,low,high,context));
  };
  const clone = (v) => JSON.parse(JSON.stringify(v));
  // All first-person values are *virtual* Godot camera-space values in metres
  // and degrees. Keep schema v1 compatible with existing user projects.
  const DEFAULT_VIEWMODEL = Object.freeze({
    position:Object.freeze([0.285,-0.225,-0.47]),
    rotation:Object.freeze([0,9,0]),
    scale:1.36,
    hand_position:Object.freeze([0.025,-0.015,0.035]),
    hand_rotation:Object.freeze([0,0,0])
  });
  function normalizeViewmodel(value = DEFAULT_VIEWMODEL) {
    if (!value || typeof value !== "object" || Array.isArray(value))
      throw new Error("Параметры первого лица должны быть объектом.");
    return {
      position:vec(value.position,-2,2,"FP позиция"),
      rotation:vec(value.rotation,-180,180,"FP поворот"),
      scale:finite(value.scale,0.05,8,"FP масштаб"),
      hand_position:vec(value.hand_position,-1,1,"FP положение кисти"),
      hand_rotation:vec(value.hand_rotation,-180,180,"FP поворот кисти")
    };
  }
  function normalAnchor(value,key) {
    if (!value || typeof value !== "object" || Array.isArray(value) || typeof value.enabled !== "boolean")
      throw new Error("Отсутствует точка крепления: "+key);
    return {
      enabled:value.enabled,
      position:vec(value.position,-100,100,key+" position"),
      rotation:vec(value.rotation,-180,180,key+" rotation")
    };
  }
  function makeAnchors() {
    const result = {};
    for (const key of Object.keys(ANCHORS)) {
      result[key] = {enabled:key==="grip_primary"||key==="forward"||key==="item_origin",
        position:[0,0,0],rotation:[0,0,0]};
    }
    return result;
  }
  function makeProject(name="Новый игровой предмет",category="sidearm",subtype="revolver",parts=[]) {
    return normalizeProject({
      format:FORMAT,version:VERSION,units:"meters",name,category,subtype,
      axis_forward:"-Z",parts,partRoles:{},anchors:makeAnchors(),
      viewmodel:normalizeViewmodel()
    });
  }
  function normalizeGameplay(value, category) {
    if (value == null) return category === "longarm"
      ? {damage:35, recoil:1.4, capacity:5, reload:1.8, sound:"heavy"}
      : {damage:20, recoil:1, capacity:7, reload:1.2, sound:"standard"};
    if (!["standard", "heavy", "muted", "silent"].includes(value.sound) || !Number.isInteger(value.capacity))
      throw new Error("Проверь звуковой профиль и ёмкость.");
    return {damage:finite(value.damage, 1, 100, "игровой урон"),
      recoil:finite(value.recoil, 0, 3, "визуальная отдача"),
      capacity:finite(value.capacity, 1, 30, "ёмкость"),
      reload:finite(value.reload, 0.3, 5, "перезарядка"), sound:value.sound};
  }

  function normalizeProject(value) {
    if (!value || typeof value !== "object" || Array.isArray(value) ||
        value.format !== FORMAT || value.version !== VERSION ||
        value.units !== "meters" || value.axis_forward !== "-Z")
      throw new Error("Это не файл Hellish Forge версии 1");
    const group = GROUPS[value.category];
    if (!group || !Object.hasOwn(group.types,value.subtype))
      throw new Error("Неизвестная категория или тип игрового предмета");
    const model = Model.normalizeProject({format:Model.FORMAT,version:Model.VERSION,
      units:"meters",name:value.name,parts:value.parts});
    const oldRoles = value.partRoles;
    if (!oldRoles || typeof oldRoles!=="object" || Array.isArray(oldRoles))
      throw new Error("Неверные роли геометрии");
    const validIds = new Set(model.parts.map((p)=>p.id));
    for(const key of Object.keys(oldRoles)) {
      if(!validIds.has(key)) throw new Error("Роль ссылается на отсутствующую деталь");
      if(!Object.hasOwn(ROLES,oldRoles[key])) throw new Error("Неизвестная роль детали: "+oldRoles[key]);
    }
    if (!value.anchors || typeof value.anchors !== "object" || Array.isArray(value.anchors))
      throw new Error("Точки крепления должны быть объектом");
    const anchors={};
    for(const key of Object.keys(ANCHORS)) anchors[key]=normalAnchor(value.anchors[key],key);
    return {
      format:FORMAT,version:VERSION,units:"meters",axis_forward:"-Z",
      name:model.name,category:value.category,subtype:value.subtype,
      parts:model.parts,partRoles:Object.fromEntries(model.parts.map((p)=>[p.id,oldRoles[p.id]||"body"])),
      ...(value.gameplay == null ? {} : {gameplay:normalizeGameplay(value.gameplay, value.category)}),
      anchors,viewmodel:normalizeViewmodel(value.viewmodel === undefined ? DEFAULT_VIEWMODEL : value.viewmodel)
    };
  }
  function toModel(data) {
    const valid=normalizeProject(data);
    return Model.makeProject(valid.name,valid.parts);
  }
  function setCategory(input, category, subtype) {
    const valid=normalizeProject(input);
    valid.category=category;
    valid.subtype=subtype;
    return normalizeProject(valid);
  }
  function previewAsset() {
    // Fictional silhouette using only abstract low-poly volumes; no functional mechanics.
    const p=makeProject("Путник / декоративный револьвер");
    p.parts=[
      Model.makePart("box",{name:"Корпус",position:[0,0.48,0],scale:[0.4,0.28,0.72],color:"#555961",metalness:0.45,roughness:0.68}),
      Model.makePart("box",{name:"Рукоять",position:[0,0.17,0.19],rotation:[25,0,0],scale:[0.22,0.54,0.24],color:"#855b43",roughness:0.94}),
      Model.makePart("cylinder",{name:"Декоративный барабан",position:[0,0.48,-0.09],rotation:[0,0,90],scale:[0.31,0.38,0.31],color:"#98949a",metalness:0.55,roughness:0.47}),
      Model.makePart("box",{name:"Передняя часть",position:[0,0.51,-0.57],scale:[0.18,0.17,0.59],color:"#6c6e77",metalness:0.65,roughness:0.53})
    ];
    p.partRoles=Object.fromEntries(p.parts.map((x,i)=>[x.id,["body","grip","cylinder","barrel"][i]]));
    p.anchors.grip_primary.position=[0,0.13,0.19];
    p.anchors.forward.position=[0,0.51,-0.9];
    p.anchors.cylinder.enabled=true;
    p.anchors.cylinder.position=[0,0.48,-0.09];
    return normalizeProject(p);
  }
  return Object.freeze({FORMAT,VERSION,STORAGE_KEY,GROUPS,ROLES,ANCHORS,ANCHOR_COLORS,
    DEFAULT_VIEWMODEL,normalizeViewmodel,normalizeGameplay,
    makeAnchors,makeProject,normalizeProject,toModel,setCategory,previewAsset});
});
