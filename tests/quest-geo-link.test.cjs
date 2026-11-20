const {test}=require("node:test");
const assert=require("node:assert/strict");
const Geo=require("../site/quest/geo-overlay-core.js");
const Editor=require("../site/map/editor-core.js");
const Quest=require("../site/quest/quest-core.js");

function square(id,category,cx,cy,size=0.0002,name="") {
  const d=size/2;
  return Editor.makeFeature(id,category,{type:"Polygon",coordinates:[[
    [cx-d,cy-d],[cx+d,cy-d],[cx+d,cy+d],[cx-d,cy+d],[cx-d,cy-d]
  ]]},name);
}
test("stable IDs and geographic centroids link Geo Lab houses, forests and water to quest steps",()=>{
  const features=[
    square("house-1","house",55.852,54.672,0.00002,"Дом старосты"),
    square("forest-1","forest",55.853,54.674),
    square("lake-1","water",55.854,54.676)
  ];
  const original=JSON.stringify(features);
  const index=Geo.objectIndex(features);
  assert.equal(index.size,3);
  const house=index.get("house-1");
  assert.ok(Math.abs(house.position.lon-55.852)<1e-9);
  assert.ok(Math.abs(house.position.lat-54.672)<1e-9);
  assert.equal(Geo.objectLabel(house),"Дом · Дом старосты");
  const step=Quest.createStep("reach","step-house");
  const bound=Geo.bindStep(step,"house-1",index,Quest);
  assert.equal(bound.objectId,"house-1");
  assert.deepEqual(bound.target,{lon:55.852,lat:54.672});
  assert.equal(step.objectId,"");
  assert.equal(Geo.resolveBinding(bound,index,Quest).status,"linked");
  assert.equal(index.get("forest-1").category,"forest");
  assert.equal(index.get("lake-1").category,"water");
  assert.equal(JSON.stringify(features),original,"Source Geo Lab geometries must not be rewritten");
});
test("road targets use line midpoint and car marker uses point coordinates",()=>{
  const road=Editor.makeFeature("road-main","road",{
    type:"LineString",coordinates:[[55.850,54.670],[55.852,54.670],[55.858,54.670]]
  });
  const car=Editor.makeFeature("car-parked","car",{
    type:"Point",coordinates:[55.85,54.671]
  });
  const index=Geo.objectIndex([road,car]);
  assert.ok(Math.abs(index.get("road-main").position.lon-55.854)<1e-8);
  assert.equal(index.get("car-parked").position.lat,54.671);
  const s=Quest.createStep("interact","interact-car");
  assert.deepEqual(Geo.bindStep(s,"car-parked",index,Quest).target,{lon:55.85,lat:54.671});
});
test("search by name, type and ID preserves original scene and returns bounded results",()=>{
  const index=Geo.objectIndex([
    square("a-home","house",55.85,54.67,0.0002,"Родной дом"),
    square("b-forest","forest",55.86,54.67),
    square("c-house","house",55.87,54.67)
  ]);
  assert.deepEqual(Geo.searchObjects(index,"родной").map(x=>x.id),["a-home"]);
  assert.deepEqual(Geo.searchObjects(index,"лес").map(x=>x.id),["b-forest"]);
  assert.deepEqual(Geo.searchObjects(index,"c-house").map(x=>x.id),["c-house"]);
  assert.equal(Geo.searchObjects(index,"").length,0);
  assert.equal(Geo.searchObjects(index,"дом",1).length,1);
});
test("moved geometry refreshes step coordinate, missing ID is reported without erasing target",()=>{
  const old=Geo.objectIndex([square("house-1","house",55.852,54.672)]);
  const step=Geo.bindStep(Quest.createStep("reach","reach-1"),"house-1",old,Quest);
  const newIndex=Geo.objectIndex([square("house-1","house",55.853,54.675)]);
  const moved=Geo.resolveBinding(step,newIndex,Quest);
  assert.equal(moved.status,"moved");
  assert.deepEqual(moved.point,{lon:55.853,lat:54.675});
  assert.deepEqual(step.target,{lon:55.852,lat:54.672});
  assert.equal(Geo.resolveBinding({...step,target:moved.point},newIndex,Quest).status,"linked");
  assert.deepEqual(Geo.resolveBinding(step,new Map(),Quest),{status:"missing",entry:null,point:null});
  assert.throws(()=>Geo.bindStep(step,"missing",old,Quest),/не найден/);
  assert.throws(()=>Geo.bindStep(Quest.createStep("message","note"),"house-1",old,Quest),/сообщению/);
});
test("Geo Lab object index ignores IDs too long for existing Quest Lab v1 schema",()=>{
  const long=square("x".repeat(121),"house",55.852,54.672);
  assert.equal(Geo.objectIndex([long]).size,0);
});
