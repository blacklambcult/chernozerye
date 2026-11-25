// Bake the same building recipes as Studio, without a preview renderer.
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const { THREE, sandbox, batchModel, encodeModel } = require("./studio_model_bake.cjs");
const root = path.resolve(__dirname, "..");
const output = path.join(root, "godot/generated_village");
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
  const model = batchModel(source, { bakeTint: type !== "zabor", atlasTextures: type !== "zabor" });
  const bytes = await encodeModel(model);
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
