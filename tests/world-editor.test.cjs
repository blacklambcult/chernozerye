const test=require("node:test"),assert=require("node:assert/strict");
const fs=require("node:fs"),path=require("node:path");
const C=require("../site/map/editor-core.js");
const A=[55.851,54.673],B=[55.8513,54.673],D=[55.8513,54.6733];
const house=()=>C.makeFeature("house-a","house",{type:"Polygon",coordinates:[[A,B,D]]},"Изба");
const recipe={version:1,generator:"building",type:"izba",parameters:{floors:2,walls:1,roof:2,window:3,door:4},conditions:{walls:"normal",roof:"normal",door:"normal",fence:"normal",window:2}};
test("recipe round trips on the same geographic ID and legacy data is unchanged",()=>{
 const a=house(),b=house();a.properties.appearance=recipe;
 const result=C.importCollection(C.collectionFromFeatures([a]))[0];
 assert.deepEqual(result.properties.appearance,recipe);assert.equal(result.id,b.id);
 assert.equal(C.normalizeFeature(b).properties.appearance,undefined);
 assert.equal(C.normalizeAppearance(recipe,"forest"),null);
 assert.equal(C.normalizeAppearance({...recipe,parameters:{...recipe.parameters,floors:5}},"house"),null);
 assert.equal(C.normalizeFeature({...a,properties:{...a.properties,appearance:{...recipe,version:3}}}),null);
 const tree={version:1,generator:"nature",type:"tree",parameters:{species:8,height:2,canopy:1,seed:4},environment:"n"};
 assert.deepEqual(C.normalizeAppearance(tree,"forest"),tree);
});
test("delta transforms move/rotate/scale actual coordinates and keep a closed polygon",()=>{
 const a=house(),g=C.transformGeometry(a.geometry,"house",{east:10,north:20,rotation:90,scale:2});
 assert.ok(g);assert.deepEqual(g.coordinates[0][0],g.coordinates[0].at(-1));
 assert.ok(Math.abs(C.measure({...a,geometry:g}).area_m2/C.measure(a).area_m2-4)<0.02);
 assert.equal(C.transformGeometry(a.geometry,"house",{scale:0}),null);
 assert.equal(C.transformGeometry(a.geometry,"house",{east:NaN}),null);
 assert.equal(C.transformGeometry({type:"Point",coordinates:[56.04999,54.673]},"car",{east:100}),null);
 const p=C.transformGeometry({type:"Point",coordinates:A},"car",{east:10});
 assert.ok(p.coordinates[0]>A[0]);assert.equal(p.coordinates[1],A[1]);
});
test("complete-world export replaces a base feature exactly once, retaining other IDs",()=>{
 const a=house(),road=C.makeFeature("r","road",{type:"LineString",coordinates:[A,B]});
 const b=house();b.properties.appearance=recipe;b.properties.name="Другая изба";
 const merged=C.mergeWorldFeatures([a,road],[b]);
 assert.equal(merged.length,2);assert.equal(merged[0].id,a.id);assert.equal(merged[0].properties.name,b.properties.name);
 assert.deepEqual(merged[0].properties.appearance,recipe);assert.deepEqual(merged[1],road);
 assert.equal(a.properties.appearance,undefined);
});
test("existing generators provide an embedded recipe interface, with no extra GLB required",()=>{
 const read=p=>fs.readFileSync(path.join(__dirname,"..",p),"utf8");
 for(const p of ["site/building-generator/index.html","site/nature-generator/index.html"]){
  const html=read(p);assert.match(html,/WorldEditorGetContext/);assert.match(html,/WorldEditorRecipe/);assert.match(html,/if\(world\)return/);
 }
 const html=read("site/map/index.html"),js=read("site/map/editor.js");
 for(const id of ["world-generator-dialog","world-transform-apply","world-export-all","world-open-generator"])assert.ok(html.includes('id="'+id+'"'));
 assert.match(js,/source!==generatorFrame.contentWindow/);
 assert.match(js,/core\.mergeWorldFeatures\(gameFeatures,records\)/);
});
