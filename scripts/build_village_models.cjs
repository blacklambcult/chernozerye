// Bake the same building recipes as Studio, without a preview renderer.
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const { THREE, sandbox, batchModel, encodeModel } = require("./studio_model_bake.cjs");
const root = path.resolve(__dirname, "..");
const crypto = require("node:crypto");
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const index = args.indexOf(name);
  if (index < 0) return fallback;
  if (!args[index + 1] || args[index + 1].startsWith("--")) throw Error("Missing " + name);
  return path.resolve(args[index + 1]);
};
const output = option("--output", path.join(root, "godot/generated_village"));
const layout = option("--layout", path.join(root, "godot/manual_layout.json"));
const recipesOnly = args.includes("--recipes-only");
const MAX_CUSTOM_MODELS = 64;
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

// The Python importer already validates the recipe. Canonicalize fields here,
// avoiding dependence on input JSON property ordering and feature names.
function buildingRecipes(features) {
  const recipes = new Map(), byFeature = Object.create(null);
  const types = {house:"izba",sauna:"banya",shed:"saray"};
  for (const feature of features) {
    if (!Object.hasOwn(types, feature.type) || !feature.appearance) continue;
    const a = feature.appearance;
    if (a.version !== 1 || a.generator !== "building" || a.type !== types[feature.type])
      throw Error("Invalid building appearance: " + feature.id);
    const keys = a.type === "izba" ? ["floors","walls","roof","window","door"] : ["walls","roof","door"];
    const modules = Object.fromEntries(keys.map(k=>[k,a.parameters[k]]));
    // Fence condition is not used by any house builder. Reuse the same asset.
    const conditions = Object.fromEntries(["walls","roof","door","window"].map(k=>[k,a.conditions[k]]));
    const recipe = {type:a.type,modules,conditions};
    const id = "recipe_" + crypto.createHash("sha256").update(JSON.stringify(recipe)).digest("hex").slice(0,24);
    recipes.set(id, recipe);
    if (Object.hasOwn(byFeature,feature.id)) throw Error("Duplicate feature: "+feature.id);
    byFeature[feature.id] = {model:id,floors:modules.floors ?? 1,window:conditions.window};
  }
  if (recipes.size > MAX_CUSTOM_MODELS)
    throw Error("Unique custom building recipes: "+recipes.size+"; budget "+MAX_CUSTOM_MODELS+". Reuse recipes before building.");
  return {recipes,byFeature};
}

async function main() {
  fs.mkdirSync(output, { recursive: true });
  if (!recipesOnly) {
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
  }
  const {features} = JSON.parse(fs.readFileSync(layout,"utf8"));
  if(!Array.isArray(features)) throw Error("Invalid manual layout");
  const {recipes,byFeature} = buildingRecipes(features);
  // Remove only previous generated custom variants, never baseline assets.
  for(const filename of fs.readdirSync(output))
    if(/^recipe_[a-f0-9]{24}\\.glb$/.test(filename) && !recipes.has(filename.slice(0,-4)))
      fs.unlinkSync(path.join(output,filename));
  for(const [id,recipe] of recipes)
    await bake(id,recipe.type,recipe.modules,{...recipe.conditions,fence:"normal"});
  fs.writeFileSync(path.join(output,"appearance_models.json"),
    JSON.stringify({version:1,features:byFeature},null,2)+"\n");
  console.log("STUDIO_VILLAGE_MODELS_READY: baseline="+(recipesOnly?0:37)+" custom="+recipes.size+" feature_overrides="+Object.keys(byFeature).length);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
