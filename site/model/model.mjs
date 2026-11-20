import { readLibraryGlb } from "./glb-import.mjs";
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { TransformControls } from "three/addons/controls/TransformControls.js";
import { GLTFExporter } from "three/addons/exporters/GLTFExporter.js";

const C = window.ChernoModelCore;
const KEY = "chernozerye.modellab.v1";
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
  throw new Error("Model Lab Core missing");
}
let project;
let startupWarning = "";
try {
  const saved = localStorage.getItem(KEY);
  project = saved ? C.normalizeProject(JSON.parse(saved)) : C.preset("crate");
} catch (error) {
  project = C.preset("crate");
  startupWarning = "Сохранённый проект повреждён; открыт образец.";
}
let selectedId = null;
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
sceneModel.name = "CHERNOZERYE_MODEL_EXPORT";
scene.add(sceneModel);
const meshById = new Map();
const transform = new TransformControls(camera, canvas);
transform.setMode(mode);
transform.setSize(0.82);
scene.add(transform);
transform.addEventListener("dragging-changed", (evt) => {
  orbit.enabled = !evt.value;
  if (!evt.value && selectedId) {
    pushUndo();
    syncFromMesh();
    renderInspector();
    renderList();
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
  select(selectedId);
  renderList();
  $("part-count").textContent = project.parts.length;
  $("viewport-title").textContent = project.name;
  $("model-name").value = project.name;
}
function select(id) {
  selectedId = id && meshById.has(id) ? id : null;
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
  $("selection-caption").textContent = part() ? part().name.toUpperCase() : "НЕТ ВЫДЕЛЕННОЙ ДЕТАЛИ";
}
function persist() {
  try {
    const checked = C.normalizeProject(project);
    project = checked;
    localStorage.setItem(KEY, JSON.stringify(checked));
    status("Сохранено локально · " + project.parts.length + " деталей");
    return true;
  } catch (error) {
    status("Ошибка сохранения: " + error.message, true);
    return false;
  }
}
function pushUndo() {
  try {
    undoHistory.push(JSON.stringify(C.normalizeProject(project)));
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
      '<span class="part-kind">' + String(i + 1).padStart(2, "0") + ' / ' + TYPE_NAMES[p.primitive] + '</span></span>' +
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
  const mesh = meshFor(copy);
  sceneModel.add(mesh);
  meshById.set(copy.id, mesh);
  select(copy.id);
  persist();
}
function useProject(next) {
  project = C.normalizeProject(next);
  selectedId = null;
  undoHistory.length = 0;
  rebuild();
  frameModel();
  persist();
}
function frameModel() {
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
  mode = next;
  transform.setMode(next);
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
  pointerStart = { x:event.clientX, y:event.clientY, button:event.button };
});
canvas.addEventListener("pointerup", (event) => {
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
  useProject(C.preset(button.dataset.preset));
}));
document.querySelectorAll("[data-mode]").forEach((button) =>
  button.addEventListener("click", () => changeMode(button.dataset.mode)));
$("toggle-grid").addEventListener("click", () => setGrid(!gridVisible));
$("frame-model").addEventListener("click", frameModel);
$("duplicate").addEventListener("click", duplicateSelected);
$("delete").addEventListener("click", deleteSelected);
$("new-project").addEventListener("click", () => {
  if (project.parts.length && !window.confirm("Создать пустую модель? Текущую сцену можно сохранить в JSON.")) return;
  useProject(C.makeProject());
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
    const data = C.normalizeProject(project);
    download(new Blob([JSON.stringify(data, null, 2) + "\n"], {type:"application/json"}), filename() + ".model.json");
    status("Скачан JSON проекта — " + data.parts.length + " деталей");
  } catch (error) { status("Ошибка JSON: " + error.message, true); }
});
$("load-json").addEventListener("change", async (event) => {
  const f = event.target.files?.[0];
  event.target.value = "";
  if (!f) return;
  if (f.size > 1024 * 1024) { status("Лимит импортируемого проекта — 1 МБ.", true); return; }
  try {
    const imported = C.normalizeProject(JSON.parse(await f.text()));
    if (project.parts.length && !window.confirm("Импорт заменит текущую модель. Продолжить?")) return;
    useProject(imported);
    status("Импортировано: " + project.parts.length + " деталей");
  } catch (error) { status("Не удалось открыть файл: " + error.message, true); }
});
async function makeGlb(data) {
  const group = new THREE.Group();
  group.name = data.name;
  try {
    for (const part of data.parts) {
      const mesh = meshFor(part);
      mesh.userData = { modelLabId: part.id, primitive: part.primitive };
      group.add(mesh);
    }
    const buffer = await new GLTFExporter().parseAsync(group, { binary: true, trs: true });
    return new Blob([buffer], { type: "model/gltf-binary" });
  } finally {
    group.traverse(obj => {
      if (obj.isMesh) { obj.geometry.dispose(); obj.material.dispose(); }
    });
  }
}
async function saveLibraryModel(name, blob) {
  const library = window.ChernoObjectLibrary;
  await library.saveModel({ id: crypto.randomUUID(), name, blob });
  void library.requestPersistence().catch(() => {});
  status("Модель в локальной библиотеке · открой «Предметы» в Quest Lab");
}

$("import-library-glb").addEventListener("click", () => $("library-glb-file").click());
$("library-glb-file").addEventListener("change", async event => {
  const file = event.target.files?.[0];
  event.target.value = "";
  if (!file) return;
  const button = $("import-library-glb");
  button.disabled = true;
  try {
    const blob = await readLibraryGlb(file);
    const name = file.name.replace(/\.glb$/i, "").trim().slice(0, 80) || "Импортированная модель";
    await saveLibraryModel(name, blob);
  } catch (error) {
    status("Не удалось импортировать GLB: " + error.message, true);
  } finally {
    button.disabled = false;
  }
});

async function publishModel(button, saveLocally) {
  if (!project.parts.length) { status("Добавь хотя бы одну деталь.", true); return; }
  button.disabled = true;
  try {
    const data = C.normalizeProject(project);
    const exportName = filename();
    const blob = await makeGlb(data);
    if (saveLocally) {
      await saveLibraryModel(data.name, blob);
    } else {
      download(blob, exportName + ".glb");
      status("GLB экспортирован · " + data.parts.length + " деталей / Godot");
    }
  } catch (error) {
    status("Не удалось сохранить модель: " + error.message, true);
  } finally {
    button.disabled = false;
  }
}
$("export-glb").addEventListener("click", event => publishModel(event.currentTarget, false));
$("save-library-model").addEventListener("click", event => publishModel(event.currentTarget, true));
window.addEventListener("keydown", (event) => {
  const target = event.target;
  if (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target?.isContentEditable) return;
  if (event.ctrlKey || event.metaKey) {
    if (event.code === "KeyD" && part()) { event.preventDefault(); duplicateSelected(); }
    else if (event.code === "KeyZ" && undoHistory.length) {
      event.preventDefault();
      const previous = undoHistory.pop();
      project = C.normalizeProject(JSON.parse(previous));
      selectedId = null;
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
function frame() {
  resize();
  orbit.update();
  if (selectionBox) selectionBox.update();
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}
rebuild();
frameModel();
persist();
if (startupWarning) status(startupWarning, true);
window.__modelLabLoaded = true;
requestAnimationFrame(frame);
console.info("MODEL_LAB_READY: primitive=5 json=true glb=true model_parts=" + project.parts.length);
