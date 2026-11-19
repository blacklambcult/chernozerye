const test=require("node:test");
const assert=require("node:assert/strict");
const Base=require("../site/model/model-core.js");
const Forge=require("../site/forge/forge-core.js");

test("all game categories include required fantasy/editor labels",()=>{
  assert.deepEqual(Object.keys(Forge.GROUPS),["edged","blunt","sidearm","longarm","special"]);
  for(const sub of ["revolver","pistol","smg"]) assert.ok(Forge.GROUPS.sidearm.types[sub]);
  for(const sub of ["shotgun","rifle","assault_rifle","machine_gun","launcher"]) assert.ok(Forge.GROUPS.longarm.types[sub]);
  for(const sub of ["crossbow","bow","throwing_spear"]) assert.ok(Forge.GROUPS.special.types[sub]);
});

test("independent Forge JSON round-trips roles and anchors in virtual metres",()=>{
  const original=Forge.previewAsset();
  assert.equal(original.format, "chernozerye.hellish-forge");
  assert.equal(original.axis_forward,"-Z");
  assert.equal(original.units,"meters");
  assert.equal(original.anchors.grip_primary.enabled,true);
  assert.equal(original.anchors.forward.enabled,true);
  assert.equal(original.parts.length,4);
  assert.equal(original.partRoles[original.parts[2].id],"cylinder");
  const read=Forge.normalizeProject(JSON.parse(JSON.stringify(original)));
  assert.deepEqual(read,original);
  assert.equal(Forge.toModel(read).parts.length,read.parts.length);
  assert.equal(Forge.toModel(read).format,Base.FORMAT);
});

test("category changes do not alter geometry or marker locations",()=>{
  const a=Forge.previewAsset();
  const switched=Forge.setCategory(a,"special","artifact");
  assert.equal(switched.category,"special");
  assert.deepEqual(switched.parts,a.parts);
  assert.deepEqual(switched.anchors,a.anchors);
  assert.throws(()=>Forge.setCategory(a,"sidearm","machine_gun"),/категория/);
});

test("invalid marker positions, IDs, roles, unsafe schema are rejected",()=>{
  const a=Forge.previewAsset();
  assert.throws(()=>Forge.normalizeProject({...a,format:"unknown"}),/Hellish Forge/);
  assert.throws(()=>Forge.normalizeProject({...a,axis_forward:"+X"}),/Hellish Forge/);
  const invalid=JSON.parse(JSON.stringify(a));
  invalid.anchors.forward.position[2]=Infinity;
  assert.throws(()=>Forge.normalizeProject(invalid),/величина/);
  const invalid2=JSON.parse(JSON.stringify(a));
  invalid2.anchors.grip_primary.rotation=[0,0,181];
  assert.throws(()=>Forge.normalizeProject(invalid2),/величина/);
  const invalid3=JSON.parse(JSON.stringify(a));
  invalid3.partRoles[invalid3.parts[1].id]="invalid";
  assert.throws(()=>Forge.normalizeProject(invalid3),/роль/);
  const invalid4=JSON.parse(JSON.stringify(a));
  invalid4.partRoles["missing-id"]="body";
  assert.throws(()=>Forge.normalizeProject(invalid4),/отсутствующую/);
});
