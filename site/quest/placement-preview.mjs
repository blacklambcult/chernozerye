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
scene.add(new THREE.GridHelper(12, 12, 0x76ced0, 0x344956));
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
  for (const child of [...pivot.children]) { pivot.remove(child); dispose(child); }
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
  draw();
};
