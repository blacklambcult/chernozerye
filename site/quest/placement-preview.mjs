import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

const canvas = document.querySelector("#placement-preview");
const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
renderer.setSize(280, 170, false);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(42, 280 / 170, 0.01, 100);
camera.position.set(3, 2.6, 4);
camera.lookAt(0, 0.6, 0);
scene.add(new THREE.HemisphereLight(0xffffff, 0x6e6256, 2.5));
scene.add(new THREE.GridHelper(100, 100, 0x76ced0, 0x344956));
const pivot = new THREE.Group();
scene.add(pivot);
let generation = 0;
function dispose(model) {
  model.traverse(node => {
    node.geometry?.dispose();
    for (const material of [node.material].flat()) material?.dispose();
  });
}
function draw() { renderer.render(scene, camera); }
window.updatePlacementPreview = (heading, scale) => {
  pivot.rotation.y = -heading * Math.PI / 180;
  pivot.scale.setScalar(scale);
  draw();
};
window.showPlacementPreview = async blob => {
  const current = ++generation;
  for (const child of [...pivot.children]) {
    if (child !== marker) { pivot.remove(child); dispose(child); }
  }
  draw();
  if (!blob) return;
  const { scene: model } = await new GLTFLoader().parseAsync(await blob.arrayBuffer(), "");
  if (current !== generation) { dispose(model); return; }
  const bounds = new THREE.Box3().setFromObject(model);
  const size = Math.max(1, bounds.getSize(new THREE.Vector3()).length());
  const center = bounds.getCenter(new THREE.Vector3());
  camera.position.copy(center).add(new THREE.Vector3(1.35, 1.1, 1.65).multiplyScalar(size));
  camera.lookAt(center);
  camera.far = Math.max(100, size * 100);
  camera.updateProjectionMatrix();
  pivot.add(model);
  if (point) renderPlacement();
  else draw();
};

// Same WGS84 / UTM 40N projection as the game placement loader.
function project(lat, lon) {
  const a = 6378137, e2 = 0.0066943799901413165, k = 0.9996;
  const phi = THREE.MathUtils.degToRad(lat);
  const sin = Math.sin(phi), cos = Math.cos(phi);
  const n = a / Math.sqrt(1 - e2 * sin * sin);
  const t = Math.tan(phi) ** 2, c = e2 / (1 - e2) * cos * cos;
  const d = cos * THREE.MathUtils.degToRad(lon - 57);
  const e4 = e2 ** 2, e6 = e2 ** 3;
  const m = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
    - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * phi)
    + (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * phi)
    - 35 * e6 / 3072 * Math.sin(6 * phi));
  return [
    k * n * (d + (1 - t + c) * d ** 3 / 6
      + (5 - 18 * t + t * t + 72 * c - 58 * e2 / (1 - e2)) * d ** 5 / 120),
    k * (m + n * Math.tan(phi) * (d * d / 2 + (5 - t + 9 * c + 4 * c * c) * d ** 4 / 24
      + (61 - 58 * t + t * t + 600 * c - 330 * e2 / (1 - e2)) * d ** 6 / 720))
  ];
}

const context = new THREE.Group();
scene.add(context);
let layoutPromise;
let anchor = "";
let point = null;
let renderedAnchor = "";
let layout;
const marker = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 32),
  new THREE.MeshBasicMaterial({ color: 0xffb863, side: THREE.DoubleSide }));
marker.rotation.x = -Math.PI / 2;
marker.position.y = 0.2;
pivot.add(marker);
marker.visible = false;
function clearContext() {
  for (const child of [...context.children]) { context.remove(child); dispose(child); }
  renderedAnchor = "";
}

function renderContext(center) {
  if (!layout || renderedAnchor === anchor) return;
  clearContext();
  renderedAnchor = anchor;
  const origin = project(layout.metadata.origin_lat, layout.metadata.origin_lon);
  const radius = 65;
  const heights = { house: 5, shed: 3.1, sauna: 2.6 };
  const colors = { house: 0x98715b, shed: 0x876a55, sauna: 0x9d7860,
    water: 0x385d69, forest: 0x36564c };
  for (const feature of layout.features) {
    if (!["road", "path", "plot", "water", "forest", "house", "shed", "sauna"].includes(feature.type)) continue;
    const points = feature.points.map(([x, y]) => [x + origin[0] - center[0], y + origin[1] - center[1]]);
    if (!points.length) continue;
    const xs = points.map(p => p[0]), ys = points.map(p => p[1]);
    if (Math.min(...xs) > radius || Math.max(...xs) < -radius ||
        Math.min(...ys) > radius || Math.max(...ys) < -radius) continue;
    if (feature.type === "road" || feature.type === "path") {
      for (let i = 1; i < points.length; i++) {
        const [x, y] = points[i - 1], [nx, ny] = points[i];
        const length = Math.hypot(nx - x, ny - y);
        if (!length) continue;
        const road = new THREE.Mesh(new THREE.BoxGeometry(length, 0.08, feature.type === "road" ? 3.8 : 1.6),
          new THREE.MeshStandardMaterial({ color: 0x695e4d }));
        road.position.set((x + nx) / 2, 0.07, -(y + ny) / 2);
        road.rotation.y = Math.atan2(ny - y, nx - x);
        context.add(road);
      }
    } else if (feature.type === "plot") {
      const vertices = points.map(([x, y]) => new THREE.Vector3(x, 0.14, -y));
      context.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(vertices),
        new THREE.LineBasicMaterial({ color: 0x94869e })));
    } else if (points.length >= 3) {
      const shape = new THREE.Shape(points.map(([x, y]) => new THREE.Vector2(x, y)));
      const height = heights[feature.type];
      const geometry = height ? new THREE.ExtrudeGeometry(shape, { depth: height, bevelEnabled: false }) :
        new THREE.ShapeGeometry(shape);
      const mesh = new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({ color: colors[feature.type] }));
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.y = 0.02;
      context.add(mesh);
    }
  }
}

function renderPlacement() {
  if (!point) { draw(); return; }
  const center = project(point.baseLat, point.baseLon);
  const draft = project(point.lat, point.lon);
  renderContext(center);
  pivot.position.set(draft[0] - center[0], 0.04, center[1] - draft[1]);
  const distance = Number(document.querySelector("#placement-context-zoom").value);
  camera.position.set(distance * 0.68, distance, distance * 0.85);
  camera.lookAt(0, 0, 0);
  draw();
}

document.querySelector("#placement-context-zoom").addEventListener("input", renderPlacement);
window.updatePlacementContext = (draft, base) => {
  const status = document.querySelector("#placement-context-status");
  if (!draft || !Number.isFinite(draft.lat) || !Number.isFinite(draft.lon)) {
    point = null;
    anchor = "";
    clearContext();
    pivot.position.set(0, 0, 0);
    marker.visible = false;
    status.textContent = "Выбери точку на карте, чтобы увидеть окружение.";
    draw();
    return;
  }
  point = { lat: draft.lat, lon: draft.lon, baseLat: base.lat, baseLon: base.lon };
  anchor = base.lat + ":" + base.lon;
  marker.visible = true;
  renderPlacement();
  if (layout) { status.textContent = "Окружение игровой карты · оранжевое кольцо — объект"; return; }
  status.textContent = "Загрузка игровой карты…";
  layoutPromise ??= fetch("./game-layout.json").then(response => {
    if (!response.ok) throw new Error("layout unavailable");
    return response.json();
  });
  layoutPromise.then(data => {
    layout = data;
    if (point) {
      status.textContent = "Окружение игровой карты · оранжевое кольцо — объект";
      renderPlacement();
    }
  }).catch(() => {
    layoutPromise = null;
    if (point) status.textContent = "Окружение игры недоступно.";
  });
};
