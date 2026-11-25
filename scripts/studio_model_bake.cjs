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


// Bake the generator's integer texture repeats into a padded atlas. Layout
// every tile on power-of-two boundaries to keep early mip levels isolated.
function buildingAtlas(model) {
  const textures = new Set();
  model.traverse(mesh => {
    if (mesh.isMesh) textures.add(mesh.material.map);
  });
  const padding = 16;
  const tiles = new Map();
  let width = 1;
  let height = 1;
  for (const texture of textures) {
    const repeat = texture?.repeat ?? new THREE.Vector2(1, 1);
    if (!Number.isInteger(repeat.x) || !Number.isInteger(repeat.y) ||
        repeat.x < 1 || repeat.y < 1 || (texture && (
          texture.offset.lengthSq() || texture.rotation || !texture.flipY)))
      throw new Error("Unsupported village atlas texture transform");
    const tile = {
      width: (texture?.image.width ?? 1) * repeat.x,
      height: (texture?.image.height ?? 1) * repeat.y,
      repeat,
    };
    tiles.set(texture, tile);
    width = Math.max(width, THREE.MathUtils.ceilPowerOfTwo(tile.width + 2 * padding));
    height = Math.max(height, THREE.MathUtils.ceilPowerOfTwo(tile.height + 2 * padding));
  }

  const columns = THREE.MathUtils.ceilPowerOfTwo(Math.ceil(Math.sqrt(tiles.size)));
  const rows = THREE.MathUtils.ceilPowerOfTwo(Math.ceil(tiles.size / columns));
  const canvas = createCanvas(width * columns, height * rows);
  const ctx = canvas.getContext("2d");
  let index = 0;
  for (const [texture, tile] of tiles) {
    tile.x = index % columns * width + padding;
    tile.y = Math.floor(index / columns) * height + padding;
    index++;
    if (texture) {
      ctx.save();
      ctx.beginPath();
      ctx.rect(tile.x - padding, tile.y - padding, tile.width + 2 * padding, tile.height + 2 * padding);
      ctx.clip();
      for (let y = -1; y <= tile.repeat.y; y++)
        for (let x = -1; x <= tile.repeat.x; x++)
          ctx.drawImage(texture.image, tile.x + x * texture.image.width, tile.y + y * texture.image.height);
      ctx.restore();
    } else {
      ctx.fillStyle = "#fff";
      ctx.fillRect(tile.x - padding, tile.y - padding, tile.width + 2 * padding, tile.height + 2 * padding);
    }
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.encoding = THREE.sRGBEncoding;
  texture.magFilter = THREE.NearestFilter;
  texture.minFilter = THREE.NearestMipmapLinearFilter;
  return { texture, tiles };
}

function reverseFaces(geometry) {
  const back = geometry.clone();
  for (const attribute of Object.values(back.attributes)) {
    const { array, itemSize } = attribute;
    for (let i = 0; i < array.length; i += itemSize * 3) {
      for (let j = 0; j < itemSize; j++) {
        const second = i + itemSize + j;
        const third = i + 2 * itemSize + j;
        [array[second], array[third]] = [array[third], array[second]];
      }
    }
  }
  const normals = back.getAttribute("normal").array;
  for (let i = 0; i < normals.length; i++) normals[i] *= -1;
  return back;
}

function batchModel(model, { bakeTint = false, atlasTextures = false, flattenFencePanels = false } = {}) {
  model.updateMatrixWorld(true);
  const groups = new Map();
  const atlas = atlasTextures ? buildingAtlas(model) : null;
  model.traverse(mesh => {
    if (!mesh.isMesh) return;
    const material = mesh.material;
    // Preserve double-sided roof trim explicitly so opaque masonry and trim
    // with the same lighting settings can share one front-face draw.
    const explicitBackfaces = atlas && material.side === THREE.DoubleSide;
    const side = explicitBackfaces ? THREE.FrontSide : material.side;
    const key = JSON.stringify([bakeTint ? null : material.color.getHex(), atlas ? null : material.map?.uuid, material.roughness,
      material.metalness, side, material.emissive.getHex(), material.emissiveIntensity]);
    let source = mesh.geometry;
    const depth = source.parameters?.depth;
    if (flattenFencePanels && source.type === "BoxGeometry" && [0.03, 0.035].includes(depth)) {
      source = source.clone();
      const faces = source.groups.filter(group => group.materialIndex === 4 || group.materialIndex === 5);
      source.setIndex(faces.flatMap(group =>
        Array.from(source.index.array.slice(group.start, group.start + group.count))));
      source.clearGroups();
    }
    const geometry = source.index ? source.toNonIndexed() : source.clone();
    if (!geometry.getAttribute("normal")) geometry.computeVertexNormals();
    if (!geometry.getAttribute("uv"))
      geometry.setAttribute("uv", new THREE.BufferAttribute(new Float32Array(geometry.getAttribute("position").count * 2), 2));
    for (const attr of Object.keys(geometry.attributes))
      if (!["position", "normal", "uv"].includes(attr)) geometry.deleteAttribute(attr);
    if (atlas) {
      const uv = geometry.getAttribute("uv");
      const tile = atlas.tiles.get(material.map);
      const image = atlas.texture.image;
      for (let i = 0; i < uv.count; i++) {
        const u = uv.getX(i);
        const v = uv.getY(i);
        if (u < -0.00001 || u > 1.00001 || v < -0.00001 || v > 1.00001)
          throw new Error("Village UV falls outside its atlas tile");
        uv.setXY(i, (tile.x + u * tile.width) / image.width,
          1 - (tile.y + (1 - v) * tile.height) / image.height);
      }
    }
    geometry.applyMatrix4(mesh.matrixWorld);
    if (bakeTint) {
      // glTF multiplies the base color (including its texture) by COLOR_0.
      // Store the original tint per vertex so different paint colors can share one draw.
      const colors = new Float32Array(geometry.getAttribute("position").count * 3);
      for (let i = 0; i < colors.length; i += 3) {
        colors[i] = material.color.r;
        colors[i + 1] = material.color.g;
        colors[i + 2] = material.color.b;
      }
      geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    }
    if (!groups.has(key)) {
      const batchMaterial = bakeTint || atlas ? material.clone() : material;
      if (atlas) {
        batchMaterial.map = atlas.texture;
        batchMaterial.side = side;
      }
      if (bakeTint) {
        batchMaterial.color.setRGB(1, 1, 1);
        batchMaterial.vertexColors = true;
      }
      groups.set(key, { material: batchMaterial, geometries: [] });
    }
    const group = groups.get(key);
    group.geometries.push(geometry);
    if (explicitBackfaces) group.geometries.push(reverseFaces(geometry));
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
