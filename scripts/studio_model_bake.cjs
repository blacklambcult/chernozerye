// Run the Studio generators with a CPU canvas and export glTF assets.
const fs = require("node:fs");
const vm = require("node:vm");
const { createCanvas } = require("@napi-rs/canvas");
const THREE = require("three");
const element = { addEventListener() {}, classList: { toggle() {}, add() {}, remove() {} }, style: {} };
const document = {
  getElementById: () => ({ ...element }),
  addEventListener() {},
  readyState: "complete",
  querySelectorAll: () => [],
  createElement(tag) {
    if (tag !== "canvas") return { ...element };
    const canvas = createCanvas(1, 1);
    canvas.toBlob = (callback, type) => callback(new Blob([canvas.toBuffer(type)], { type }));
    return canvas;
  },
};
class FileReader {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then(result => {
      this.result = result;
      this.onloadend();
    });
  }
}
const sandbox = { THREE, document, FileReader, Blob, HTMLCanvasElement: createCanvas(1, 1).constructor, ArrayBuffer, Float32Array, Uint8Array, Uint16Array, Uint32Array, console,
  setTimeout, clearTimeout, innerWidth: 800, innerHeight: 600, addEventListener() {} };
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const addon of ["exporters/GLTFExporter.js", "utils/BufferGeometryUtils.js"])
  vm.runInContext(fs.readFileSync(require.resolve("three/examples/js/" + addon), "utf8"), sandbox);

function batchModel(model) {
  model.updateMatrixWorld(true);
  const groups = new Map();
  model.traverse(mesh => {
    if (!mesh.isMesh) return;
    const material = mesh.material;
    const key = JSON.stringify([material.color.getHex(), material.map?.uuid, material.roughness,
      material.metalness, material.side, material.emissive.getHex(), material.emissiveIntensity]);
    const geometry = mesh.geometry.index ? mesh.geometry.toNonIndexed() : mesh.geometry.clone();
    if (!geometry.getAttribute("normal")) geometry.computeVertexNormals();
    if (!geometry.getAttribute("uv"))
      geometry.setAttribute("uv", new THREE.BufferAttribute(new Float32Array(geometry.getAttribute("position").count * 2), 2));
    for (const attr of Object.keys(geometry.attributes))
      if (!["position", "normal", "uv"].includes(attr)) geometry.deleteAttribute(attr);
    geometry.applyMatrix4(mesh.matrixWorld);
    if (!groups.has(key)) groups.set(key, { material, geometries: [] });
    groups.get(key).geometries.push(geometry);
  });
  const result = new THREE.Group();
  for (const { material, geometries } of groups.values()) {
    const geometry = THREE.BufferGeometryUtils.mergeBufferGeometries(geometries);
    if (!geometry) throw new Error("Failed to merge " + model.name);
    result.add(new THREE.Mesh(THREE.BufferGeometryUtils.mergeVertices(geometry), material));
  }
  return result;
}


function encodeModel(model, animations = []) {
  return new Promise(resolve =>
    new THREE.GLTFExporter().parse(model, resolve, { binary: true, animations, onlyVisible: false }));
}
module.exports = { THREE, sandbox, batchModel, encodeModel };
