// Export the forest palette from the same builders used by Nature Studio.
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const { sandbox, batchModel, encodeModel } = require("./studio_model_bake.cjs");

const root = path.resolve(__dirname, "..");
const output = path.join(root, "godot/generated_forest");
const html = fs.readFileSync(path.join(root, "site/nature-generator/index.html"), "utf8");
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
const initialization = "                rebuildScene();\n                resetCamera();\n                handleResize();";
if (!source.includes(initialization)) throw new Error("Nature Studio initialization changed");
vm.runInContext(source.replace(initialization, `
                window.bakeNature = (recipe) => {
                    state.cat = recipe.category;
                    Object.assign(state[state.cat], recipe.parameters);
                    rebuildScene();
                    return { model: currentRoot, animations: mysticClips };
                };
                return;
`), sandbox);

async function bake(name, category, parameters) {
  const { model, animations } = sandbox.bakeNature({ category, parameters });
  if (!model) throw new Error("Missing model: " + name);
  // Keep the shrine's named hierarchy so Godot can play the Studio clips.
  const animated = category === "mystic" && parameters.altarState === "active";
  const bytes = await encodeModel(animated ? model : batchModel(model), animated ? animations : []);
  fs.writeFileSync(path.join(output, name + ".glb"), Buffer.from(bytes));
}

async function main() {
  fs.mkdirSync(output, { recursive: true });
  for (let i = 0; i < 5; i++)
    await bake("pine_" + i, "tree", { species: 1, height: i === 4 ? 1 : 2, canopy: i % 2, seed: i });
  await bake("birch", "tree", { species: 0, height: 1, canopy: 2, seed: 2 });
  for (const [i, species] of [0, 1, 2, 4].entries())
    await bake("understory_" + i, "bush", { species, group: 0, density: 2, seed: i });
  for (const [i, species] of [0, 1, 5, 7].entries())
    await bake("ground_" + i, "rock", { species, size: 1, moss: 1, seed: i });
  for (let i = 0; i < 4; i++)
    for (const altarState of ["active", "broken"])
      await bake("shrine_" + i + "_" + altarState, "mystic", { shrine: i, altarState, seed: i });
  console.log("STUDIO_FOREST_MODELS_READY: 22");
}
main().catch(error => { console.error(error); process.exitCode = 1; });
