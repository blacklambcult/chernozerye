import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { TransformControls } from "three/addons/controls/TransformControls.js";
import { GLTFExporter } from "three/addons/exporters/GLTFExporter.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

const C = window.ChernoModelCore;
const Forge = window.ChernoHellishForge;
const KEY = Forge.STORAGE_KEY;
let transferred = null;
const $ = (id) => document.getElementById(id);
const TYPE_NAMES = { box:"КУБ", cylinder:"ЦИЛИНДР", sphere:"СФЕРА", cone:"КОНУС", plane:"ПЛОСКОСТЬ" };
const TYPE_GLYPHS = { box:"▣", cylinder:"▥", sphere:"◉", cone:"△", plane:"▱" };
const safe = (text) => String(text).replace(/[&<>"']/g, (c) =>
  ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
const status = (value, warning = false) => {
  $("save-status").textContent = value;
  $("save-status").classList.toggle("warn", warning);
  $("global-status").textContent = value;
};
const download = (blob, filename) => {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1200);
};
function filename() {
  const clean = project.name.trim().toLowerCase().replace(/[^a-z0-9а-яё_-]+/gi, "-").replace(/^-+|-+$/g, "");
  return (clean || "chernozerye-prop").slice(0, 50);
}
if (!C) {
  $("webgl-error").hidden = false;
  throw new Error("Forge requires Model Lab geometry core");
}
let project;
let forgeMeta;
let startupWarning = "";
function readForgeDocument(input) {
  const data=Forge.normalizeProject(input);
  forgeMeta={category:data.category,subtype:data.subtype,partRoles:{...data.partRoles},
    anchors:JSON.parse(JSON.stringify(data.anchors)),
    gameplay:data.gameplay, viewmodel:JSON.parse(JSON.stringify(data.viewmodel))};
  project=C.makeProject(data.name,data.parts);
}
function forgeDocument() {
  const ids=new Set(project.parts.map(p=>p.id));
  const partRoles=Object.fromEntries(Object.entries(forgeMeta.partRoles).filter(([id])=>ids.has(id)));
  return Forge.normalizeProject({
    format:Forge.FORMAT,version:Forge.VERSION,units:"meters",axis_forward:"-Z",
    name:project.name,parts:project.parts,category:forgeMeta.category,
    subtype:forgeMeta.subtype,partRoles,anchors:forgeMeta.anchors,
    gameplay:forgeMeta.gameplay, viewmodel:forgeMeta.viewmodel
  });
}
try {
  const saved=localStorage.getItem(KEY);
  readForgeDocument(saved?JSON.parse(saved):Forge.previewAsset());
} catch (error) {
  readForgeDocument(Forge.previewAsset());
  startupWarning="Сохранённый проект Forge не прочитан — открыт демонстрационный силуэт.";
}
let selectedId = null;
let selectedAnchorKey = null;
let anchorChoice = "grip_primary";
let fpPreviewActive = false;
let savedEditorView = null;
let mode = "translate";
let gridVisible = true;
const undoHistory = [];
const MAX_UNDO = 32;

const scene = new THREE.Scene();
scene.background = new THREE.Color("#10191d");
scene.fog = new THREE.Fog("#10191d", 18, 45);
const camera = new THREE.PerspectiveCamera(45, 1, 0.025, 150);
camera.position.set(4.8, 3.6, 6.2);
const canvas = $("viewport");
const renderer = new THREE.WebGLRenderer({ canvas, antialias:true, alpha:false, powerPreference:"high-performance" });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.38;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const orbit = new OrbitControls(camera, canvas);
orbit.enableDamping = true;
orbit.dampingFactor = 0.085;
orbit.minDistance = 1;
orbit.maxDistance = 65;
orbit.maxPolarAngle = Math.PI * 0.92;
orbit.target.set(0, 0.9, 0);
orbit.update();
scene.add(new THREE.HemisphereLight(0xbcd0d4, 0x3f3328, 2.05));
const keyLight = new THREE.DirectionalLight(0xffd6b2, 3.2);
keyLight.position.set(-4, 9, 6);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(1024, 1024);
keyLight.shadow.camera.left = -12;
keyLight.shadow.camera.right = 12;
keyLight.shadow.camera.top = 12;
keyLight.shadow.camera.bottom = -12;
keyLight.shadow.bias = -0.0004;
scene.add(keyLight);
const fillLight = new THREE.DirectionalLight(0x8babb4, 1.45);
fillLight.position.set(5, 4, -6);
scene.add(fillLight);
const floor = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), new THREE.MeshStandardMaterial({
  color:"#17252a", metalness:0.06, roughness:0.94
}));
floor.name = "Editor floor (not exported)";
floor.rotation.x = -Math.PI / 2;
floor.position.y = -0.022;
floor.receiveShadow = true;
scene.add(floor);
const grid = new THREE.GridHelper(30, 30, "#49636a", "#28383e");
grid.position.y = 0.002;
grid.material.transparent = true;
grid.material.opacity = 0.54;
scene.add(grid);
const axes = new THREE.AxesHelper(0.95);
axes.position.set(0, 0.009, 0);
axes.visible = false;
scene.add(axes);

const sceneModel = new THREE.Group();
sceneModel.name = "CHERNOZERYE_FORGE_ASSET";
scene.add(sceneModel);
const anchorGroup=new THREE.Group();
anchorGroup.name="Forge helper markers (editor only)";
scene.add(anchorGroup);
const anchorsInScene=new Map();
function buildAnchorMarkers() {
  for(const object of anchorsInScene.values()) anchorGroup.remove(object);
  anchorsInScene.clear();
  for(const [key,label] of Object.entries(Forge.ANCHORS)) {
    const marker=new THREE.Group();
    marker.name="Editor marker / "+label;
    marker.userData.anchorKey=key;
    const color=Forge.ANCHOR_COLORS[key];
    marker.add(new THREE.Mesh(new THREE.OctahedronGeometry(0.075,0),
      new THREE.MeshBasicMaterial({color,depthTest:false})));
    marker.add(new THREE.ArrowHelper(new THREE.Vector3(0,0,-1),
      new THREE.Vector3(),0.3,new THREE.Color(color).getHex(),0.12,0.07));
    anchorGroup.add(marker);
    anchorsInScene.set(key,marker);
  }
}
function syncAnchorMarkers() {
  for(const [key,marker] of anchorsInScene){
    const data=forgeMeta.anchors[key];
    marker.position.fromArray(data.position);
    marker.rotation.set(...data.rotation.map(THREE.MathUtils.degToRad),"XYZ");
    marker.visible=data.enabled;
  }
}
buildAnchorMarkers();
const meshById = new Map();
const transform = new TransformControls(camera, canvas);
transform.setMode(mode);
transform.setSize(0.82);
scene.add(transform);
transform.addEventListener("dragging-changed", (evt) => {
  orbit.enabled = !evt.value;
  if(!evt.value) {
    if(selectedAnchorKey) {syncFromAnchor();renderAnchorInspector();}
    else if(selectedId) {syncFromMesh();renderInspector();renderList();}
    persist();
  }
});
let selectionBox = null;
function part() { return project.parts.find((p) => p.id === selectedId) || null; }
function makeGeometry(type) {
  switch (type) {
    case "box": return new THREE.BoxGeometry(1, 1, 1);
    case "cylinder": return new THREE.CylinderGeometry(0.5, 0.5, 1, 8, 1, false);
    case "sphere": return new THREE.SphereGeometry(0.5, 12, 8);
    case "cone": return new THREE.ConeGeometry(0.5, 1, 6, 1);
    case "plane": return new THREE.PlaneGeometry(1, 1);
    default: throw new Error("Unknown primitive: " + type);
  }
}
function meshFor(data) {
  const material = new THREE.MeshStandardMaterial({
    color: data.color, roughness: data.roughness, metalness: data.metalness,
    side: data.primitive === "plane" ? THREE.DoubleSide : THREE.FrontSide,
    flatShading: true
  });
  const mesh = new THREE.Mesh(makeGeometry(data.primitive), material);
  mesh.name = data.name;
  mesh.userData.modelLabPartId = data.id;
  mesh.userData.primitive = data.primitive;
  mesh.position.fromArray(data.position);
  mesh.rotation.set(...data.rotation.map(THREE.MathUtils.degToRad), "XYZ");
  mesh.scale.fromArray(data.scale);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}
function clearModel() {
  transform.detach();
  if (selectionBox) { scene.remove(selectionBox); selectionBox.geometry.dispose(); selectionBox.material.dispose(); selectionBox = null; }
  for (const mesh of meshById.values()) {
    sceneModel.remove(mesh);
    mesh.geometry.dispose();
    mesh.material.dispose();
  }
  meshById.clear();
}
function rebuild() {
  clearModel();
  sceneModel.name = project.name;
  for (const p of project.parts) {
    const mesh = meshFor(p);
    sceneModel.add(mesh);
    meshById.set(p.id, mesh);
  }
  if (!meshById.has(selectedId)) selectedId = null;
  syncAnchorMarkers();
  select(selectedId);
  renderList();
  renderForgeMetadata();
  renderAnchorInspector();
  renderFpInspector();
  updateDimensions();
  if(fpPreviewActive) updateFpPreview();
  $("part-count").textContent = project.parts.length;
  $("viewport-title").textContent = project.name;
  $("model-name").value = project.name;
}
function select(id) {
  selectedId = id && meshById.has(id) ? id : null;
  selectedAnchorKey = null;
  transform.detach();
  if (selectionBox) {
    scene.remove(selectionBox);
    selectionBox.geometry.dispose();
    selectionBox.material.dispose();
    selectionBox = null;
  }
  const mesh = meshById.get(selectedId);
  if (mesh) {
    transform.attach(mesh);
    selectionBox = new THREE.BoxHelper(mesh, 0xffc28a);
    scene.add(selectionBox);
  }
  renderList();
  renderInspector();
  if(fpPreviewActive) transform.detach();
  $("selection-caption").textContent = part() ? part().name.toUpperCase() : "ВЫБЕРИ ДЕТАЛЬ ИЛИ МАРКЕР";
}
function persist() {
  try {
    if (transferred) {
      updateFpPreview();
      return true;
    }
    const checked=forgeDocument();
    project=C.makeProject(checked.name,checked.parts);
    forgeMeta={category:checked.category,subtype:checked.subtype,partRoles:{...checked.partRoles},
      anchors:JSON.parse(JSON.stringify(checked.anchors)),
      gameplay:checked.gameplay, viewmodel:JSON.parse(JSON.stringify(checked.viewmodel))};
    localStorage.setItem(KEY,JSON.stringify(checked));
    updateDimensions();
    if(fpPreviewActive) updateFpPreview();
    status("HELLISH FORGE · "+project.parts.length+" деталей, "+Object.values(forgeMeta.anchors).filter(a=>a.enabled).length+" маркеров");
    return true;
  } catch (error) {
    status("Ошибка сохранения: " + error.message, true);
    return false;
  }
}
function pushUndo() {
  try {
    undoHistory.push(JSON.stringify(forgeDocument()));
    if (undoHistory.length > MAX_UNDO) undoHistory.shift();
  } catch { /* intermediate field edits are validated on blur */ }
}
function renderList() {
  const rows = $("object-list");
  if (!project.parts.length) {
    rows.innerHTML = '<p class="empty-list">Сцена пустая. Добавь примитив или выбери готовый шаблон.</p>';
  } else {
    rows.innerHTML = project.parts.map((p, i) =>
      '<button type="button" class="part-row' + (p.id === selectedId ? ' selected' : '') +
      '" data-select="' + safe(p.id) + '">' +
      '<span class="part-icon">' + TYPE_GLYPHS[p.primitive] + '</span>' +
      '<span class="part-desc"><span class="part-name">' + safe(p.name) + '</span>' +
      '<span class="part-kind">' + String(i + 1).padStart(2, "0") + ' / ' + TYPE_NAMES[p.primitive] +
      ' · ' + safe(Forge.ROLES[forgeMeta.partRoles[p.id]||"body"]) + '</span></span>' +
      '<span class="part-color" style="background:' + p.color + '"></span></button>').join("");
  }
  $("duplicate").disabled = $("delete").disabled = !part();
  $("part-count").textContent = project.parts.length;
}
function renderInspector() {
  const p = part();
  $("part-inspector").hidden = !p;
  $("empty-inspector").hidden = !!p;
  if (!p) return;
  $("part-kind").textContent = TYPE_NAMES[p.primitive];
  $("part-name").value = p.name;
  $("part-id").textContent = p.id;
  $("part-role").value=forgeMeta.partRoles[p.id]||"body";
  for (const input of document.querySelectorAll("input[data-field]")) {
    const v = p[input.dataset.field][Number(input.dataset.index)];
    input.value = String(Math.round(v * 1000) / 1000);
  }
  $("part-color").value = p.color;
  $("color-hex").textContent = p.color.toUpperCase();
  $("metalness").value = String(p.metalness);
  $("roughness").value = String(p.roughness);
  $("metalness-output").value = Math.round(p.metalness * 100) + "%";
  $("roughness-output").value = Math.round(p.roughness * 100) + "%";
  $("swatches").innerHTML = C.PALETTE.map((color) =>
    '<button type="button" class="swatch' + (p.color === color ? " chosen" : "") + '" ' +
    'data-color="' + color + '" style="background:' + color + '" aria-label="Цвет ' + color + '" ' +
    'title="' + color + '"></button>').join("");
}
function applyToMesh() {
  const p = part(), mesh = meshById.get(selectedId);
  if (!p || !mesh) return;
  mesh.name = p.name;
  mesh.position.fromArray(p.position);
  mesh.rotation.set(...p.rotation.map(THREE.MathUtils.degToRad), "XYZ");
  mesh.scale.fromArray(p.scale);
  mesh.material.color.set(p.color);
  mesh.material.metalness = p.metalness;
  mesh.material.roughness = p.roughness;
  mesh.material.needsUpdate = true;
  if (selectionBox) selectionBox.update();
  updateDimensions();
}
const wrapDegrees = (angle) => Math.round(THREE.MathUtils.euclideanModulo(angle + 180, 360) - 180);
function syncFromMesh() {
  const p = part(), mesh = meshById.get(selectedId);
  if (!p || !mesh) return;
  const clamp = (value, lo, hi) => Math.round(THREE.MathUtils.clamp(value, lo, hi) * 10000) / 10000;
  p.position = mesh.position.toArray().map((x) => clamp(x, -100, 100));
  p.rotation = [mesh.rotation.x, mesh.rotation.y, mesh.rotation.z].map((x) => wrapDegrees(THREE.MathUtils.radToDeg(x)));
  p.scale = mesh.scale.toArray().map((x) => clamp(Math.abs(x), 0.02, 40));
  applyToMesh();
}
function addPrimitive(type) {
  if (project.parts.length >= C.MAX_PARTS) { status("Лимит 128 деталей на модель.", true); return; }
  pushUndo();
  const newPart = C.makePart(type);
  project.parts.push(newPart);
  forgeMeta.partRoles[newPart.id]="body";
  const mesh = meshFor(newPart);
  meshById.set(newPart.id, mesh);
  sceneModel.add(mesh);
  select(newPart.id);
  persist();
}
function deleteSelected() {
  if (!part()) return;
  pushUndo();
  project.parts = project.parts.filter((p) => p.id !== selectedId);
  delete forgeMeta.partRoles[selectedId];
  selectedId = null;
  rebuild();
  persist();
}
function duplicateSelected() {
  if (!part()) return;
  if (project.parts.length >= C.MAX_PARTS) { status("Лимит 128 деталей на модель.", true); return; }
  pushUndo();
  const copy = C.clonePart(part());
  project.parts.push(copy);
  forgeMeta.partRoles[copy.id]=forgeMeta.partRoles[selectedId]||"body";
  const mesh = meshFor(copy);
  sceneModel.add(mesh);
  meshById.set(copy.id, mesh);
  select(copy.id);
  persist();
}
function useProject(next) {
  readForgeDocument(next);
  selectedId = null;
  selectedAnchorKey = null;
  undoHistory.length = 0;
  rebuild();
  frameModel();
  persist();
}
function frameModel() {
  if(fpPreviewActive) return;
  const bounds = new THREE.Box3().setFromObject(sceneModel);
  const center = bounds.isEmpty() ? new THREE.Vector3(0, 0.8, 0) : bounds.getCenter(new THREE.Vector3());
  const size = bounds.isEmpty() ? 2 : bounds.getSize(new THREE.Vector3()).length();
  orbit.target.copy(center);
  camera.position.copy(center).add(new THREE.Vector3(1, 0.84, 1.25).normalize().multiplyScalar(
    THREE.MathUtils.clamp(size * 1.8, 3.3, 38)));
  camera.near = 0.025;
  camera.far = Math.max(150, size * 10);
  camera.updateProjectionMatrix();
  orbit.update();
}
function changeMode(next) {
  if(fpPreviewActive) return;
  mode = next;
  transform.setMode(selectedAnchorKey && next==="scale" ? "translate" : next);
  for (const b of document.querySelectorAll("[data-mode]")) {
    const active = b.dataset.mode === next;
    b.classList.toggle("active", active);
    b.setAttribute("aria-pressed", String(active));
  }
}
function setGrid(show) {
  gridVisible = show;
  grid.visible = show;
  $("toggle-grid").classList.toggle("active", show);
  $("toggle-grid").setAttribute("aria-pressed", String(show));
}
let pointerStart = null;
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
canvas.addEventListener("pointerdown", (event) => {
  if(fpPreviewActive) return;
  pointerStart = { x:event.clientX, y:event.clientY, button:event.button };
});
canvas.addEventListener("pointerup", (event) => {
  if(fpPreviewActive) return;
  if (!pointerStart || pointerStart.button !== 0 ||
      Math.hypot(event.clientX - pointerStart.x, event.clientY - pointerStart.y) > 4 ||
      transform.dragging || transform.axis) {
    pointerStart = null;
    return;
  }
  pointerStart = null;
  const rect = canvas.getBoundingClientRect();
  pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -((event.clientY - rect.top) / rect.height * 2 - 1));
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObjects([...meshById.values()], false)[0];
  select(hit?.object.userData.modelLabPartId || null);
});
canvas.addEventListener("contextmenu", (event) => event.preventDefault());

$("object-list").addEventListener("click", (evt) => {
  const selected = evt.target.closest("[data-select]");
  if (selected) select(selected.dataset.select);
});
document.querySelectorAll("[data-primitive]").forEach((button) =>
  button.addEventListener("click", () => addPrimitive(button.dataset.primitive)));
document.querySelectorAll("[data-preset]").forEach((button) => button.addEventListener("click", () => {
  if (project.parts.length && !window.confirm("Заменить текущую модель выбранным шаблоном?")) return;
  useProject(button.dataset.preset==="forge_demo"?Forge.previewAsset():Forge.makeProject());
}));
document.querySelectorAll("[data-mode]").forEach((button) =>
  button.addEventListener("click", () => changeMode(button.dataset.mode)));
$("toggle-grid").addEventListener("click", () => setGrid(!gridVisible));
$("frame-model").addEventListener("click", frameModel);
$("duplicate").addEventListener("click", duplicateSelected);
$("delete").addEventListener("click", deleteSelected);
$("new-project").addEventListener("click", () => {
  if (project.parts.length && !window.confirm("Создать пустую модель? Текущую сцену можно сохранить в JSON.")) return;
  useProject(Forge.makeProject());
});
$("model-name").addEventListener("change", (evt) => {
  try {
    const next = C.normalizeProject({ ...project, name:evt.target.value });
    pushUndo();
    project = next;
    sceneModel.name = project.name;
    $("viewport-title").textContent = project.name;
    persist();
  } catch (error) { status(error.message, true); evt.target.value = project.name; }
});
$("part-name").addEventListener("change", (evt) => {
  if (!part()) return;
  try {
    const next = C.normalizePart({ ...part(), name:evt.target.value });
    pushUndo();
    Object.assign(part(), next);
    applyToMesh();
    renderList();
    persist();
  } catch (error) { status(error.message, true); }
  renderInspector();
});
document.querySelectorAll("input[data-field]").forEach((input) => {
  input.addEventListener("change", () => {
    const p = part();
    if (!p) return;
    try {
      if (input.value.trim() === "") throw new Error("Введи число.");
      const value = Number(input.value);
      const values = [...p[input.dataset.field]];
      values[Number(input.dataset.index)] = value;
      const next = C.normalizePart({ ...p, [input.dataset.field]:values });
      pushUndo();
      Object.assign(p, next);
      applyToMesh();
      persist();
    } catch (error) { status(error.message, true); }
    renderInspector();
  });
});
function updateMaterial(field, value) {
  const p = part(); if (!p) return;
  try {
    const next = C.normalizePart({ ...p, [field]:value });
    pushUndo();
    Object.assign(p, next);
    applyToMesh();
    renderInspector();
    renderList();
    persist();
  } catch (error) { status(error.message, true); }
}
$("part-color").addEventListener("change", (evt) => updateMaterial("color", evt.target.value));
$("swatches").addEventListener("click", (evt) => {
  const swatch = evt.target.closest("[data-color]");
  if (swatch) updateMaterial("color", swatch.dataset.color);
});
for (const field of ["metalness","roughness"]) {
  $(field).addEventListener("input", () => {
    const p = part(); if (!p) return;
    p[field] = Number($(field).value);
    meshById.get(selectedId).material[field] = p[field];
    $(field + "-output").value = Math.round(p[field] * 100) + "%";
  });
  $(field).addEventListener("change", () => updateMaterial(field, Number($(field).value)));
}
$("reset-transform").addEventListener("click", () => {
  const p = part(); if (!p) return;
  pushUndo();
  Object.assign(p, C.normalizePart({ ...p, position:[0,0.5,0], rotation:[0,0,0], scale:[1,1,1] }));
  applyToMesh(); renderInspector(); persist();
});
$("save-json").addEventListener("click", () => {
  try {
    const data=forgeDocument();
    download(new Blob([JSON.stringify(data, null, 2) + "\n"], {type:"application/json"}), filename() + ".forge.json");
    status("Скачан JSON проекта — " + data.parts.length + " деталей");
  } catch (error) { status("Ошибка JSON: " + error.message, true); }
});
$("load-json").addEventListener("change", async (event) => {
  const f = event.target.files?.[0];
  event.target.value = "";
  if (!f) return;
  if (f.size > 1024 * 1024) { status("Лимит импортируемого проекта — 1 МБ.", true); return; }
  try {
    const imported = Forge.normalizeProject(JSON.parse(await f.text()));
    if (project.parts.length && !window.confirm("Импорт заменит текущую модель. Продолжить?")) return;
    useProject(imported);
    status("Импортировано: " + project.parts.length + " деталей");
  } catch (error) { status("Не удалось открыть файл: " + error.message, true); }
});
const GAME_MODEL_KEY = "chernozerye.forge.game-model.v1";
async function exportForgeGlb(data) {
    // Export only the digital prop: no floor, visible debug arrows, or gizmos.
    const exportGroup=new THREE.Group();
    exportGroup.name="HF_ASSET_"+data.name;
    exportGroup.userData={forgeSchema:Forge.FORMAT,forgeVersion:Forge.VERSION,
      category:data.category,subtype:data.subtype,units:"meters",forwardAxis:"-Z",
      viewmodel:data.viewmodel};
    for(const p of data.parts){
      const mesh=meshFor(p);
      mesh.userData={forgePartId:p.id,role:data.partRoles[p.id],primitive:p.primitive};
      exportGroup.add(mesh);
    }
    // GLB named transform nodes become Marker3D/Node3D attachment references in Godot.
    for(const [key,marker] of Object.entries(data.anchors)){
      if(!marker.enabled)continue;
      const node=new THREE.Object3D();
      node.name="HF_"+key.toUpperCase();
      node.position.fromArray(marker.position);
      node.rotation.set(...marker.rotation.map(THREE.MathUtils.degToRad),"XYZ");
      node.userData={forgeAnchor:key,forwardAxis:"-Z",purpose:Forge.ANCHORS[key]};
      exportGroup.add(node);
    }
    try {
      const buffer = await new GLTFExporter().parseAsync(exportGroup, { binary:true, trs:true });
      return new Blob([buffer], { type:"model/gltf-binary" });
    } finally {
      exportGroup.traverse(obj => {
        if (obj.isMesh) { obj.geometry.dispose(); obj.material.dispose(); }
      });
    }
}

async function deliverModel(button, inGame) {
  if (!project.parts.length) { status("Добавь хотя бы одну деталь.", true); return; }
  button.disabled = true;
  try {
    const data = forgeDocument();
    if (inGame && !["sidearm", "longarm"].includes(data.category)) return;
    const blob = await exportForgeGlb(data);
    if (!inGame) { download(blob, filename() + ".glb"); status("GLB экспортирован."); return; }
    if (blob.size > 2 * 1024 * 1024) throw new Error("Для локальной отправки GLB должен быть до 2 МБ.");
    const url = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(blob);
    });
    localStorage.setItem(GAME_MODEL_KEY, JSON.stringify({ version:1, name:data.name,
      category:data.category, viewmodel:data.viewmodel, glb:url.split(",")[1],
      gameplay:Forge.normalizeGameplay(data.gameplay, data.category) }));
    status("Образец отправлен. Перезапусти игру в этом браузере и выбери слот 3.");
  } catch (error) { status("Не удалось подготовить GLB: " + error.message, true); }
  finally { button.disabled = inGame && !["sidearm", "longarm"].includes(forgeMeta.category); }
}

$("export-glb").addEventListener("click", event => deliverModel(event.currentTarget, false));
$("send-game-model").addEventListener("click", () => saveCatalogWeapon(true));
$("reset-game-model").addEventListener("click", async () => {
  const slot = Number($("game-slot").value);
  try {
    await window.ChernoObjectLibrary.removeForgeSlot(slot);
    const legacy = JSON.parse(localStorage.getItem(GAME_MODEL_KEY) || "null");
    if (legacy && (legacy.slot ?? 3) === slot) localStorage.removeItem(GAME_MODEL_KEY);
    await refreshForgeAssignments();
    feedback.textContent = "Назначение снято. Перезапусти игру.";
  } catch (error) { feedback.textContent = error.message; }
});
window.addEventListener("keydown", (event) => {
  const target = event.target;
  if (fpPreviewActive || target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target?.isContentEditable) return;
  if (event.ctrlKey || event.metaKey) {
    if (event.code === "KeyD" && part()) { event.preventDefault(); duplicateSelected(); }
    else if (event.code === "KeyZ" && undoHistory.length) {
      event.preventDefault();
      const previous = undoHistory.pop();
      readForgeDocument(JSON.parse(previous));
      selectedId=null;
      selectedAnchorKey=null;
      rebuild();
      persist();
      status("Отменено последнее действие");
    }
    return;
  }
  if (event.code === "KeyW") changeMode("translate");
  else if (event.code === "KeyE") changeMode("rotate");
  else if (event.code === "KeyR") changeMode("scale");
  else if (event.code === "KeyF") frameModel();
  else if (event.code === "Delete" || event.code === "Backspace") {
    event.preventDefault(); deleteSelected();
  } else if (event.code === "Escape") select(null);
});
let lastCanvasWidth = -1;
let lastCanvasHeight = -1;
function resize() {
  const bounds = canvas.getBoundingClientRect();
  const w = Math.max(1, Math.floor(bounds.width));
  const h = Math.max(1, Math.floor(bounds.height));
  // setSize works in CSS pixels; canvas.width is in *device* pixels.
  // Comparing those values would resize the WebGL renderer every frame on HiDPI screens.
  if (w === lastCanvasWidth && h === lastCanvasHeight) return;
  lastCanvasWidth = w;
  lastCanvasHeight = h;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
new ResizeObserver(resize).observe(canvas);
const animationClock = new THREE.Clock();
function frame() {
  const delta = Math.min(animationClock.getDelta(), 0.05);
  transferred?.mixer.update(delta);
  resize();
  if(!fpPreviewActive) orbit.update();
  if (selectionBox) selectionBox.update();
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

/* Forge-only inspector and virtual Godot marker handling. */
const groupSelect=$("forge-group");
const subtypeSelect=$("forge-subtype");
const roleSelect=$("part-role");
const anchorSelect=$("anchor-key");
let meshBounds = new THREE.Box3();

function updateDimensions() {
  meshBounds.setFromObject(sceneModel);
  if(meshBounds.isEmpty()) {
    $("model-size").textContent="ГАБАРИТЫ / НЕТ ГЕОМЕТРИИ";
    return;
  }
  const size=meshBounds.getSize(new THREE.Vector3());
  const format=(v)=>(Math.round(v*1000)/1000).toFixed(3);
  $("model-size").textContent="РАЗМЕР / X "+format(size.x)+" × Y "+format(size.y)+" × Z "+format(size.z)+" м";
}
function renderForgeMetadata() {
  if(!groupSelect.options.length) {
    for(const [key,group] of Object.entries(Forge.GROUPS)){
      groupSelect.add(new Option(group.label,key));
    }
  }
  groupSelect.value=forgeMeta.category;
  const group=Forge.GROUPS[forgeMeta.category];
  subtypeSelect.innerHTML="";
  for(const [key,label] of Object.entries(group.types)){
    subtypeSelect.add(new Option(label,key));
  }
  subtypeSelect.value=forgeMeta.subtype;
}
function renderAnchorInspector() {
  if(!anchorSelect.options.length) {
    for(const [key,label] of Object.entries(Forge.ANCHORS))
      anchorSelect.add(new Option(label,key));
  }
  anchorSelect.value=anchorChoice;
  const marker=forgeMeta.anchors[anchorChoice];
  $("anchor-enabled").checked=marker.enabled;
  for(const input of document.querySelectorAll("[data-anchor-field]")) {
    const type=input.dataset.anchorField;
    const i=Number(input.dataset.anchorIndex);
    input.value=String(Math.round(marker[type][i]*1000)/1000);
    input.disabled=!marker.enabled;
  }
  $("anchor-edit").disabled=!marker.enabled;
  $("anchor-caption").textContent=marker.enabled ?
    "HF_"+anchorChoice.toUpperCase()+" · Цифровой маркер, ось −Z вперёд" :
    "Маркер отключён и не будет экспортирован в GLB.";
}
function updateAnchorData(key,field,array) {
  const old=JSON.parse(JSON.stringify(forgeMeta.anchors[key]));
  forgeMeta.anchors[key][field]=array;
  try {
    const verified=forgeDocument();
    forgeMeta.anchors[key]=verified.anchors[key];
    syncAnchorMarkers();
    persist();
  } catch(err) {
    forgeMeta.anchors[key]=old;
    status("Неверный маркер: "+err.message,true);
  }
  renderAnchorInspector();
}
function focusAnchor(key) {
  const marker=anchorsInScene.get(key);
  if(!marker)return;
  if(!forgeMeta.anchors[key].enabled){
    forgeMeta.anchors[key].enabled=true;
    syncAnchorMarkers();
  }
  selectedAnchorKey=key;
  transform.detach();
  transform.setMode(mode==="scale"?"translate":mode);
  transform.attach(marker);
  $("selection-caption").textContent="МАРКЕР · "+Forge.ANCHORS[key].toUpperCase();
  renderAnchorInspector();
  persist();
}
function syncFromAnchor() {
  const key=selectedAnchorKey;
  if(!key)return;
  const obj=anchorsInScene.get(key);
  if(!obj)return;
  const fix=(v,low,high)=>Math.round(THREE.MathUtils.clamp(v,low,high)*10000)/10000;
  forgeMeta.anchors[key].position=obj.position.toArray().map(v=>fix(v,-100,100));
  forgeMeta.anchors[key].rotation=[
    obj.rotation.x,obj.rotation.y,obj.rotation.z
  ].map(v=>fix(wrapDegrees(THREE.MathUtils.radToDeg(v)),-180,180));
  syncAnchorMarkers();
}
for(const [role,label] of Object.entries(Forge.ROLES)) {
  roleSelect.add(new Option(label,role));
}
roleSelect.addEventListener("change",(evt)=>{
  const p=part();
  if(!p)return;
  pushUndo();
  forgeMeta.partRoles[p.id]=evt.target.value;
  renderList();
  persist();
});
groupSelect.addEventListener("change",(evt)=>{
  if(!Object.hasOwn(Forge.GROUPS,evt.target.value))return;
  pushUndo();
  forgeMeta.category=evt.target.value;
  forgeMeta.subtype=Object.keys(Forge.GROUPS[forgeMeta.category].types)[0];
  renderFpInspector();
  renderForgeMetadata();
  persist();
});
subtypeSelect.addEventListener("change",(evt)=>{
  pushUndo();
  forgeMeta.subtype=evt.target.value;
  persist();
});
anchorSelect.addEventListener("change",(evt)=>{
  anchorChoice=evt.target.value;
  if(selectedAnchorKey) {
    selectedAnchorKey=null;
    transform.detach();
    if(part())transform.attach(meshById.get(selectedId));
  }
  renderAnchorInspector();
});
$("anchor-enabled").addEventListener("change",(evt)=>{
  pushUndo();
  const a=forgeMeta.anchors[anchorChoice];
  a.enabled=evt.target.checked;
  if(!a.enabled && selectedAnchorKey===anchorChoice){
    selectedAnchorKey=null;
    transform.detach();
  }
  syncAnchorMarkers();
  renderAnchorInspector();
  persist();
});
for(const input of document.querySelectorAll("[data-anchor-field]")){
  input.addEventListener("change",()=>{
    const key=anchorChoice;
    const data=forgeMeta.anchors[key];
    const field=input.dataset.anchorField;
    const i=Number(input.dataset.anchorIndex);
    const values=[...data[field]];
    if(input.value.trim()==="") {renderAnchorInspector();return;}
    values[i]=Number(input.value);
    pushUndo();
    updateAnchorData(key,field,values);
  });
}
$("anchor-edit").addEventListener("click",()=>{
  if(!forgeMeta.anchors[anchorChoice].enabled)return;
  focusAnchor(anchorChoice);
});
$("anchor-snap").addEventListener("click",()=>{
  const mesh=meshById.get(selectedId);
  if(!mesh){
    status("Сначала выбери нужную деталь в списке или на модели.",true);
    return;
  }
  pushUndo();
  updateAnchorData(anchorChoice,"position",mesh.position.toArray());
});


/* A real camera-space preview of the same transform hierarchy used by
 * godot/forge_pistol.gd. Separate from the editable world-space scene. */
const fpRoot = new THREE.Group();
fpRoot.name = "EditorOnlyFirstPersonPreview";
fpRoot.visible = false;
scene.add(fpRoot);

function fpSegment(parent, name, start, end, radius, endRadius, color) {
  const a=new THREE.Vector3(...start), b=new THREE.Vector3(...end);
  const d=b.clone().sub(a);
  const material=new THREE.MeshStandardMaterial({color,roughness:0.95,metalness:0,flatShading:true});
  const geometry=new THREE.CylinderGeometry(endRadius,radius,d.length(),6,1);
  const mesh=new THREE.Mesh(geometry,material);
  mesh.name=name;
  mesh.position.copy(a.clone().add(b).multiplyScalar(.5));
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),d.normalize());
  mesh.castShadow=false;
  parent.add(mesh);
}
function fpHandGeometry(parent) {
  const wrist=[.052,-.062,.071];
  const cuff=[.087,-.130,.136];
  const elbow=[.215,-.385,.285];
  const upper=[.275,-.555,.410];
  fpSegment(parent,"Sleeve",upper,elbow,.095,.076,"#545849");
  fpSegment(parent,"Forearm",elbow,cuff,.082,.060,"#3c4239");
  fpSegment(parent,"Cuff",[.100,-.150,.162],[.072,-.108,.118],.072,.068,"#393d36");
  fpSegment(parent,"Palm",wrist,[.005,-.023,.013],.058,.045,"#a18a7c");
  fpSegment(parent,"Thumb",[.009,-.054,.054],[-.045,-.012,-.063],.025,.018,"#a18a7c");
  for(let i=0;i<4;i++){
    const x=(i-1.5)*.023;
    fpSegment(parent,"Finger"+i,[x,-.018,.028],[x-.008,-.084,-.028],.016,.012,"#847065");
  }
}
function clearFpPreview() {
  transferred?.scene.removeFromParent();
  for (const child of [...fpRoot.children]) {
    fpRoot.remove(child);
    child.traverse((node)=>{
      if(node.isMesh) {
        node.geometry.dispose();
        if(Array.isArray(node.material)) node.material.forEach(m=>m.dispose());
        else node.material.dispose();
      }
    });
  }
}
function updateFpPreview() {
  if(!fpPreviewActive) return;
  clearFpPreview();
  const vm=forgeMeta.viewmodel;
  fpRoot.position.fromArray(vm.position);
  fpRoot.rotation.set(...vm.rotation.map(THREE.MathUtils.degToRad),"XYZ");
  const importedModel = new THREE.Group();
  importedModel.name = "ForgePreviewImportedAsset";
  importedModel.scale.setScalar(vm.scale);
  // The imported GLB is centred at HF_GRIP_PRIMARY by the Godot viewmodel.
  const grip = forgeMeta.anchors.grip_primary.enabled ?
    forgeMeta.anchors.grip_primary.position : [0,0,0];
  if (transferred) importedModel.add(transferred.scene);
  else importedModel.position.set(-grip[0]*vm.scale,-grip[1]*vm.scale,-grip[2]*vm.scale);
  for(const p of document.querySelector(".forge-transfer") ? [] : project.parts) {
    const mesh=meshFor(p);
    mesh.castShadow=false;
    importedModel.add(mesh);
  }
  fpRoot.add(importedModel);
  const hand=new THREE.Group();
  hand.name="WeaponRightHand";
  hand.position.fromArray(vm.hand_position);
  hand.rotation.set(...vm.hand_rotation.map(THREE.MathUtils.degToRad),"XYZ");
  fpHandGeometry(hand);
  fpRoot.add(hand);
}
function renderFpInspector() {
  if(!forgeMeta?.viewmodel) return;
  const vm=forgeMeta.viewmodel;
  for(const input of document.querySelectorAll("[data-fp-field]")) {
    const field=input.dataset.fpField;
    const index=Number(input.dataset.fpIndex);
    input.value=String(vm[field][index]);
    if (input.type === "range") input.nextElementSibling.value = Number(input.value).toFixed(3) + " м";
  }
  $("fp-scale").value=String(vm.scale);
  $("fp-scale-slider").value=String(vm.scale);
  $("fp-scale-output").value=vm.scale.toFixed(3)+"×";
  $("fp-preview-toggle").classList.toggle("active",fpPreviewActive);
  $("fp-preview-toggle").setAttribute("aria-pressed",String(fpPreviewActive));
  $("fp-preview-panel").classList.toggle("active",fpPreviewActive);
  $("fp-preview-panel").textContent=fpPreviewActive ?
    "▤ Вернуться в редактор модели" : "◉ Включить предпросмотр в руке";
  $("fp-preview-overlay").hidden=!fpPreviewActive;
}
function toggleFpPreview() {
  fpPreviewActive=!fpPreviewActive;
  if(fpPreviewActive){
    savedEditorView={
      position:camera.position.clone(),quaternion:camera.quaternion.clone(),
      target:orbit.target.clone(),fov:camera.fov
    };
    orbit.enabled=false;
    camera.position.set(0,0,0);
    camera.quaternion.identity();
    camera.fov=75;
    camera.updateProjectionMatrix();
    sceneModel.visible=false;
    anchorGroup.visible=false;
    floor.visible=false;
    grid.visible=false;
    axes.visible=false;
    transform.visible=false;
    if(selectionBox) selectionBox.visible=false;
    fpRoot.visible=true;
    updateFpPreview();
  }else{
    clearFpPreview();
    fpRoot.visible=false;
    sceneModel.visible=true;
    anchorGroup.visible=true;
    floor.visible=true;
    grid.visible=gridVisible;
    transform.visible=true;
    if(selectionBox) selectionBox.visible=true;
    if(savedEditorView){
      camera.position.copy(savedEditorView.position);
      camera.quaternion.copy(savedEditorView.quaternion);
      camera.fov=savedEditorView.fov;
      orbit.target.copy(savedEditorView.target);
      camera.updateProjectionMatrix();
    }
    orbit.enabled=true;
    // Clear selection gizmo state after returning to editing mode.
    selectedAnchorKey=null;
    select(selectedId);
  }
  $("frame-model").disabled=fpPreviewActive;
  for(const button of document.querySelectorAll("[data-mode]"))button.disabled=fpPreviewActive;
  $("toggle-grid").disabled=fpPreviewActive;
  $("viewport-hint").textContent=fpPreviewActive ?
    "ПРЕДПРОСМОТР ИГРЫ · FOV 75° · Положение и масштаб редактируются в панели справа" :
    "ЛКМ — выбрать деталь · ПКМ — обзор · Колёсико — приблизить · W/E/R — инструменты";
  renderFpInspector();
}
function changeViewmodel(field, value) {
  try {
    const checked=Forge.normalizeViewmodel({...forgeMeta.viewmodel,[field]:value});
    if (!transferred) pushUndo();
    forgeMeta.viewmodel=checked;
    persist();
    renderFpInspector();
  }catch(error){
    status("Поза от первого лица: "+error.message,true);
    renderFpInspector();
  }
}
for(const input of document.querySelectorAll("[data-fp-field]")){
  if (["position", "hand_position"].includes(input.dataset.fpField)) {
    const limit = input.dataset.fpField === "position" ? 2 : 1;
    input.type = "range";
    input.min = String(-limit);
    input.max = String(limit);
    input.step = ".001";
    input.after(document.createElement("output"));
  }
  input.addEventListener(input.type === "range" ? "input" : "change",()=>{
    const field=input.dataset.fpField;
    const values=[...forgeMeta.viewmodel[field]];
    if(input.value.trim()==="") {renderFpInspector();return;}
    values[Number(input.dataset.fpIndex)]=Number(input.value);
    changeViewmodel(field,values);
  });
}
$("fp-scale").addEventListener("change",()=>{
  const input=$("fp-scale");
  if(input.value.trim()==="") {renderFpInspector();return;}
  changeViewmodel("scale",Number(input.value));
});
$("fp-scale-slider").addEventListener("input",event=>{
  const v=Number(event.target.value);
  $("fp-scale-output").value=v.toFixed(3)+"×";
  // Slider changes preview continuously, including hand position.
  changeViewmodel("scale",v);
});
$("fp-preview-toggle").addEventListener("click",toggleFpPreview);
$("fp-preview-panel").addEventListener("click",toggleFpPreview);
$("fp-reset").addEventListener("click",()=>{
  pushUndo();
  forgeMeta.viewmodel=Forge.normalizeViewmodel();
  persist();
  renderFpInspector();
});
const GAME_FP_KEY = "chernozerye.forge.game-viewmodel.v1";

function currentFpProfile() {
  return { format: "chernozerye.forge.viewmodel", version: 1, viewmodel: forgeDocument().viewmodel };
}
$("apply-fp-profile").addEventListener("click", () => {
  try {
    localStorage.setItem(GAME_FP_KEY, JSON.stringify(currentFpProfile()));
    status("Профиль применится к модели в руках при следующем запуске игры в этом браузере.");
  } catch (error) { status("Не удалось сохранить игровой профиль: " + error.message, true); }
});
$("clear-game-fp-profile").addEventListener("click", () => {
  try {
    localStorage.removeItem(GAME_FP_KEY);
    status("При следующем запуске игра загрузит штатный профиль.");
  } catch (error) { status("Не удалось сбросить профиль: " + error.message, true); }
});
$("import-fp-profile").addEventListener("change", async event => {
  const file = event.target.files?.[0];
  event.target.value = "";
  if (!file) return;
  try {
    if (file.size > 16384) throw new Error("Файл больше 16 КБ.");
    const profile = JSON.parse(await file.text());
    if (profile?.format !== "chernozerye.forge.viewmodel" || profile.version !== 1 || !profile.viewmodel)
      throw new Error("Нужен FP-профиль Hellish Forge версии 1.");
    const viewmodel = Forge.normalizeViewmodel(profile.viewmodel);
    pushUndo();
    forgeMeta.viewmodel = viewmodel;
    persist();
    renderFpInspector();
    status("Профиль открыт в редакторе. Нажми «Применить FP-профиль в игре» для проверки.");
  } catch (error) { status("Ошибка импорта FP-профиля: " + error.message, true); }
});

$("export-fp-profile").addEventListener("click",()=>{
  try {
    const profile = currentFpProfile();
    download(new Blob([JSON.stringify(profile,null,2)+"\n"],{type:"application/json"}),
      filename()+".viewmodel.json");
    status("Профиль положения в руках сохранён. Его можно подключить в Godot.");
  }catch(err){status("Ошибка экспорта FP-профиля: "+err.message,true);}
});

rebuild();
frameModel();
if (startupWarning) status(startupWarning, true);
window.__hellishForgeLoaded = true;
requestAnimationFrame(frame);

const catalog = $("weapon-library");
const clipPicker = $("weapon-clip");
clipPicker.addEventListener("change", () => {
  if (!transferred) return;
  transferred.mixer.stopAllAction();
  const clip = transferred.clips[Number(clipPicker.value)];
  if (clipPicker.value !== "" && clip) {
    const action = transferred.mixer.clipAction(clip);
    action.reset().setLoop(THREE.LoopOnce, 1).play();
  }
});
const feedback = $("transfer-status");
const profileButtons = ["save-transferred-asset", "send-game-model"];
const numericFields = {
  damage:[1,100], recoil:[0,3], capacity:[1,30], reload:[0.3,5],
  weight:[0.1,20], rate:[60,1200], noise:[0,100],
  pushback:[0,3], recovery:[0.25,3], inertia:[0,3], impact:[0,3], bodycam:[0,1]
};
const choiceFields = ["class","grip","mode","sound"];

function readWeaponProfile() {
  const values = {};
  for (const [key,[min,max]] of Object.entries(numericFields)) {
    const value = $("game-" + key).valueAsNumber;
    if (!Number.isFinite(value) || value < min || value > max ||
        (["capacity","rate","noise"].includes(key) && !Number.isInteger(value)))
      throw new Error("Проверь поле «" + $("game-" + key).labels[0].textContent + "».");
    values[key] = value;
  }
  for (const key of choiceFields) values[key] = $("game-" + key).value;
  if (values.sound === "silent") values.noise = 0;
  return {...values, ...Forge.normalizeGameplay(values, values.grip), bodycamProfile:2};
}

const forgeAssignments = new Map();
const soundFields = {fire:"Выстрел", cock:"Взвод", reload:"Перезарядка", empty:"Попытка выстрела без патронов"};
const defaultSoundPreview = {
  revolver: {fire:"revolver_shot.ogg", cock:"revolver_cock.ogg", reload:"revolver_cylinder.ogg", empty:"revolver_empty.ogg"},
  pistol: {fire:"pistol_shot.ogg", cock:"pistol_cock.ogg", reload:"pistol_reload.ogg", empty:"pistol_empty.ogg"}
};
const soundPanel = $("weapon-audio");
const soundPreview = new Audio();
let soundPreviewUrl;
function stopSoundPreview() {
  soundPreview.pause();
  soundPreview.removeAttribute("src");
  if (soundPreviewUrl) URL.revokeObjectURL(soundPreviewUrl);
  soundPreviewUrl = null;
}

$("game-class").addEventListener("change", () => {
  stopSoundPreview();
  renderWeaponSounds();
});

function renderWeaponSounds() {
  for (const action of Object.keys(soundFields)) {
    const sound = transferred?.sounds[action];
    $("sound-name-" + action).textContent = sound?.name ?? "Звук по умолчанию";
    $("sound-play-" + action).disabled = !sound && !(transferred && defaultSoundPreview[$("game-class").value]?.[action]);
    $("sound-clear-" + action).disabled = !sound;
  }
}

for (const [action, title] of Object.entries(soundFields)) {
  const row = document.createElement("div");
  row.innerHTML = `<label>${title}<input type="file" accept=".wav,.ogg,.mp3"></label>
    <p id="sound-name-${action}"></p>
    <button type="button" id="sound-play-${action}">Прослушать</button>
    <button type="button" id="sound-clear-${action}">Сбросить</button>`;
  soundPanel.append(row);
  const input = row.querySelector("input");
  input.addEventListener("change", () => {
    const file = input.files[0];
    input.value = "";
    if (!file || !transferred) return;
    const format = file.name.split(".").pop().toLowerCase();
    if (!["wav","ogg","mp3"].includes(format) || !file.size || file.size > 512 * 1024) {
      feedback.textContent = "Выбери WAV, OGG Vorbis или MP3 размером до 512 КБ.";
      return;
    }
    transferred.sounds[action] = {name:file.name, format, blob:file};
    feedback.textContent = "Звук добавлен. Сохрани профиль или отправь модель в игру.";
    renderWeaponSounds();
  });
  $("sound-play-" + action).addEventListener("click", () => {
    const sound = transferred?.sounds[action];
    if (!sound && !(transferred && defaultSoundPreview[$("game-class").value]?.[action])) return;
    stopSoundPreview();
    if (sound) soundPreviewUrl = URL.createObjectURL(sound.blob);
    soundPreview.src = soundPreviewUrl ?? new URL("./audio/" + defaultSoundPreview[$("game-class").value][action], import.meta.url).href;
    soundPreview.play().catch(() => { feedback.textContent = "Браузер не смог воспроизвести этот файл."; });
  });
  $("sound-clear-" + action).addEventListener("click", () => {
    if (!transferred) return;
    stopSoundPreview();
    delete transferred.sounds[action];
    renderWeaponSounds();
  });
}
async function refreshForgeAssignments() {
  const records = await window.ChernoObjectLibrary.forgeSlots();
  forgeAssignments.clear();
  for (const record of records) forgeAssignments.set(record.slot, record);
  for (const option of $("game-slot").options) {
    const slot = Number(option.value);
    const label = slot === 10 ? "10 (клавиша 0)" : option.value;
    option.textContent = label + " — " + (forgeAssignments.get(slot)?.name ?? "свободна");
  }
}

function fillWeaponProfile(record) {
  const slots = Array.from($("game-slot").options, option => Number(option.value));
  const assigned = slots.find(slot => forgeAssignments.get(slot)?.modelId === record.id);
  const preferred = Number(record.slot);
  const free = slots.find(slot => !forgeAssignments.has(slot));
  const slot = assigned ?? (slots.includes(preferred) && !forgeAssignments.has(preferred) ? preferred : free);
  $("game-slot").value = slot == null ? "" : String(slot);
  const type = record.recipe?.weaponType;
  const classes = Array.from($("game-class").options, option => option.value);
  const defaultClass = classes.includes(type) ? type : "other";
  const grip = ["pistol","revolver"].includes(defaultClass) ? "sidearm" : "longarm";
  const old = record.recipe?.gameplay ?? {};
  const specs = {...Forge.normalizeGameplay(null, grip), class:defaultClass, grip,
    pushback:1, recovery:1, inertia:1, impact:1, bodycam:0.8,
    mode:"single", weight:grip === "sidearm" ? 1 : 3, rate:260, noise:old.sound === "muted" ? 20 : 100,
    ...old, ...record.gameplay};
  if (!classes.includes(specs.class)) specs.class = defaultClass;
  if (specs.bodycam === 0 && specs.bodycamProfile !== 2) specs.bodycam = 0.8;
  for (const key of [...Object.keys(numericFields), ...choiceFields])
    $("game-" + key).value = specs[key];
}

let catalogRequest = 0;
const weapons = new Map();
async function openCatalogWeapon(id) {
  const request = ++catalogRequest;
  stopSoundPreview();
  soundPanel.disabled = true;
  clipPicker.length = 1;
  clipPicker.disabled = true;
  for (const button of profileButtons) $(button).disabled = true;
  if (fpPreviewActive) clearFpPreview();
  transferred = null;
  const record = weapons.get(id);
  if (!record) { feedback.textContent = "Выбери модель или создай её в генераторе."; return; }
  feedback.textContent = "Загрузка модели…";
  try {
    const [gltf] = await Promise.all([
      new GLTFLoader().parseAsync(await record.blob.arrayBuffer(), ""),
      refreshForgeAssignments()
    ]);
    if (request !== catalogRequest) return;
    forgeMeta.viewmodel = Forge.normalizeViewmodel(record.viewmodel ?? {
      ...Forge.DEFAULT_VIEWMODEL, scale: record.recipe?.gameplay?.scale ?? Forge.DEFAULT_VIEWMODEL.scale
    });
    transferred = {record, sounds:{...record.sounds}, scene:gltf.scene, clips:gltf.animations, mixer:new THREE.AnimationMixer(gltf.scene)};
    soundPanel.disabled = false;
    gltf.animations.forEach((clip, index) => clipPicker.add(new Option(clip.name, String(index))));
    clipPicker.disabled = gltf.animations.length === 0;
    $("transferred-name").value = record.name;
    $("viewport-title").textContent = record.name;
    if (!fpPreviewActive) toggleFpPreview();
    else { updateFpPreview(); renderFpInspector(); }
    fillWeaponProfile(record);
    renderWeaponSounds();
    for (const button of profileButtons) $(button).disabled = false;
    feedback.textContent = "";
  } catch (error) {
    if (request === catalogRequest) feedback.textContent = "Ошибка загрузки: " + error.message;
  }
}

async function refreshWeaponLibrary() {
  const selected = transferred?.record.id || catalog.value || new URLSearchParams(location.search).get("weapon");
  try {
    const records = await window.ChernoObjectLibrary.models();
    weapons.clear();
    catalog.length = 1;
    for (const record of records.filter(item => item.kind === "weapon").sort((a,b) => a.name.localeCompare(b.name))) {
      weapons.set(record.id, record);
      catalog.add(new Option(record.name, record.id));
    }
    catalog.value = weapons.has(selected) ? selected : "";
    if (!transferred && catalog.value) await openCatalogWeapon(catalog.value);
    else if (!transferred) feedback.textContent = "Выбери модель или создай её в генераторе.";
  } catch (error) { feedback.textContent = "Не удалось открыть библиотеку: " + error.message; }
}
catalog.addEventListener("change", () => openCatalogWeapon(catalog.value));
$("game-sound").addEventListener("change", () => {
  if ($("game-sound").value === "silent") $("game-noise").value = "0";
});
window.addEventListener("focus", refreshWeaponLibrary);
document.addEventListener("visibilitychange", () => { if (!document.hidden) refreshWeaponLibrary(); });

async function saveCatalogWeapon(sendToGame) {
  if (!transferred) return;
  const record = transferred.record;
  const button = $(sendToGame ? "send-game-model" : "save-transferred-asset");
  button.disabled = true;
  try {
    const name = $("transferred-name").value.trim();
    if (!name) throw new Error("Введи название варианта.");
    const gameplay = readWeaponProfile();
    const viewmodel = Forge.normalizeViewmodel(forgeMeta.viewmodel);
    const slot = Number($("game-slot").value);
    if (sendToGame && (!Number.isInteger(slot) || slot < 3 || slot > 10))
      throw new Error("Выбери тестовую ячейку. Если все заняты, выбери, какую заменить.");
    const saved = {...record, name, gameplay, viewmodel, sounds:{...transferred.sounds},
      slot:slot || record.slot, updatedAt:new Date().toISOString()};
    await window.ChernoObjectLibrary.saveModel(saved);
    weapons.set(saved.id, saved);
    if (transferred?.record.id === saved.id) {
      transferred.record = saved;
      catalog.selectedOptions[0].textContent = name;
      $("viewport-title").textContent = name;
    }
    if (sendToGame) {
      if (saved.blob.size > 2 * 1024 * 1024) throw new Error("В библиотеке сохранено. Для отправки в игру требуется GLB до 2 МБ.");
      await window.ChernoObjectLibrary.saveForgeSlot({id:slot, modelId:saved.id, version:1, name, blob:saved.blob, slot,
        category:gameplay.grip, gameplay, viewmodel, sounds:saved.sounds, weaponType:saved.recipe?.weaponType});
      await refreshForgeAssignments();
    }
    feedback.textContent = sendToGame ? "Профиль сохранён. Перезапусти игру и нажми " + (slot === 10 ? 0 : slot) + "." : "Профиль сохранён в библиотеке.";
  } catch (error) { feedback.textContent = error.message; }
  finally { button.disabled = !transferred; }
}
$("save-transferred-asset").addEventListener("click", () => saveCatalogWeapon(false));
for (const id of profileButtons) $(id).disabled = true;
for (const id of ["fp-preview-panel", "apply-fp-profile", "clear-game-fp-profile"])
  $(id).hidden = true;
toggleFpPreview();
refreshWeaponLibrary();
