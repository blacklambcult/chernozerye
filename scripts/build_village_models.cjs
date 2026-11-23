// Bake the same building recipes as Studio, without a preview renderer.
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const { createCanvas } = require("@napi-rs/canvas");
const THREE = require("three");
const root = path.resolve(__dirname, "..");
const output = path.join(root, "godot/generated_village");
const element = { addEventListener() {}, classList: { toggle() {}, add() {}, remove() {} }, style: {} };
const document = {
  getElementById: () => ({ ...element }),
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
  innerWidth: 800, innerHeight: 600, addEventListener() {} };
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const addon of ["exporters/GLTFExporter.js", "utils/BufferGeometryUtils.js"])
  vm.runInContext(fs.readFileSync(require.resolve("three/examples/js/" + addon), "utf8"), sandbox);

const html = fs.readFileSync(path.join(root, "site/building-generator/index.html"), "utf8");
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
// Use the production builders and materials, bypassing UI and the frame loop.
const initialization = "                rebuildScene();\n                resetCamera();\n                handleResize();";
if (!source.includes(initialization)) throw new Error("Studio initialization changed");
vm.runInContext(source.replace(initialization, `
                window.bakeBuilding = (recipe) => {
                    state.buildingType = recipe.type;
                    Object.assign(state[recipe.type], recipe.modules);
                    Object.assign(state.conditions, recipe.conditions);
                    rebuildScene();
                    return currentModelRoot;
                };
                return;
`).replace("window.addEventListener('load', init3D);", "init3D();"), sandbox);

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

async function bake(id, type, modules, conditions) {
  const source = sandbox.bakeBuilding({ type, modules, conditions });
  if (type === "saray" && source.getObjectByName("Windows"))
    throw new Error(id + " contains a shed window");
  if ((type === "izba" && [1, 2, 3].includes(modules.door)) ||
      (type === "banya" && modules.door === 1)) {
    const annex = source.getObjectByName("GroundedAnnex");
    if (!annex || Math.abs(new THREE.Box3().setFromObject(annex).min.y) > 0.00001)
      throw new Error(id + " has a floating annex");
  }
  const model = batchModel(source);
  const bytes = await new Promise(resolve =>
    new THREE.GLTFExporter().parse(model, resolve, { binary: true }));
  fs.writeFileSync(path.join(output, id + ".glb"), Buffer.from(bytes));
}

async function main() {
  fs.mkdirSync(output, { recursive: true });
  const profiles = [
    ["ruined", "normal", "normal", 3], ["normal", "ruined", "ruined", 4],
    ["normal", "ruined", "normal", 3], ["ruined", "normal", "ruined", 4],
    ["normal", "normal", "normal", 1], ["ruined", "ruined", "ruined", 2],
    ["cultist", "cultist", "cultist", 2],
  ];
  for (const [type, variants] of Object.entries({ izba: 5, banya: 3, saray: 3 })) {
    for (let i = 0; i < profiles.length; i++) {
      const [walls, roof, door, window] = profiles[i];
      const modules = { walls: i % variants, roof: (i + 2) % variants,
        door: (i + 1) % (type === "banya" ? 2 : variants) };
      if (type === "izba") {
        modules.window = (i + 3) % variants;
        for (const floors of [1, 2])
          await bake(type + floors + "_" + i, type, { ...modules, floors }, { walls, roof, door, window });
      } else await bake(type + "_" + i, type, modules, { walls, roof, door, window });
    }
  }
  for (const fence of ["normal", "ruined", "cultist"])
    for (let mat = 0; mat < 3; mat++)
      await bake("fence_" + fence + "_" + mat, "zabor", { mat, form: 0, span: 1.65 }, { fence });
  console.log("STUDIO_VILLAGE_MODELS_READY: 37");
}
main().catch(error => { console.error(error); process.exitCode = 1; });
