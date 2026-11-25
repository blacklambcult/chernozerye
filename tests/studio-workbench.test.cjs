const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const read=p=>fs.readFileSync(path.join(__dirname,"..",p),"utf8");
const catalog=require("../site/studio/asset-catalog.js");
const core=require("../site/quest/quest-core.js");
test("catalog computes placement usage without modifying records or creating copies of binary assets",()=>{
  const models=[{id:"a",name:"Изба",source:"buildings",blob:{size:2048}},{id:"b",name:"Сосна",source:"nature",blob:{size:1024}}];
  const placements=[{modelId:"a"},{modelId:"a"},{modelId:"missing"}];
  const before=JSON.stringify({models,placements});
  const d=catalog.summarize(models,placements);
  assert.equal(d.items.length,2);assert.equal(d.placements,3);assert.equal(d.missing,1);assert.equal(d.bytes,3072);
  assert.equal(d.items.find(i=>i.id==="a").used,2);
  assert.equal(d.items.find(i=>i.id==="b").used,0);
  assert.equal(catalog.filter(d.items,{query:"ИЗБА",used:"yes"}).length,1);
  assert.equal(catalog.filter(d.items,{source:"nature",used:"no"})[0].id,"b");
  assert.deepEqual(catalog.filter(d.items,{source:"nature",used:"yes"}),[]);
  assert.equal(catalog.formatBytes(2048),"2.0 КБ");
  assert.equal(JSON.stringify({models,placements}),before);
  assert.ok(d.items.every(i=>!("blob" in i)));
});
test("workbenches retain stable DOM IDs and opt in to common CSS",()=>{
  for(const [htmlPath,scripts] of [["site/map/index.html",["site/map/editor.js","site/map/app.js"]],["site/quest/index.html",["site/quest/quest.js"]],["site/studio/index.html",["site/studio/asset-catalog.js"]]]){
    const html=read(htmlPath),ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
    assert.equal(new Set(ids).size,ids.length);
    for(const src of scripts)for(const m of read(src).matchAll(/\$\("([^"]+)"\)/g))assert.ok(ids.includes(m[1]),src+":"+m[1]);
    if(!htmlPath.includes("/studio/"))assert.ok(html.includes("../studio/workbench.css?v=3"));
  }
  const map=read("site/map/index.html");
  assert.ok(map.indexOf("geo-outline")<map.indexOf('id="editor-objects"'));
  assert.ok(map.indexOf("geo-tools-bar")<map.indexOf('id="draw-hint"'));
  assert.ok(map.indexOf("geo-inspector")<map.indexOf('id="editor-selected"'));
  const quest=read("site/quest/index.html");
  assert.equal((quest.match(/data-library="/g)||[]).length,5);
  assert.ok(quest.includes('data-library="placement"'));
  assert.ok(quest.indexOf("placement-inspector")<quest.indexOf('id="local-placement-edit"'));
  assert.ok(quest.indexOf("character-inspector")<quest.indexOf('id="character-fields"'));
});
test("placement workspace does not expose narrative coordinate edits",()=>{
  const context={library:"placement",quest:{},step:{type:"reach"},worldItem:{type:"item"},geoAvailable:true};
  assert.equal(core.mapModeError("browse",context),"");
  for(const mode of ["spawn","step","object","world_place"])assert.notEqual(core.mapModeError(mode,context),"");
});
