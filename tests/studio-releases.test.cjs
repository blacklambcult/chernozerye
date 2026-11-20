const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const R=require("../site/studio/release-core.js");
const doc=JSON.parse(fs.readFileSync(path.join(__dirname,"../site/studio/releases.json"),"utf8"));

test("release manifest includes current published Studio version",()=>{
  assert.equal(R.normalize(doc),doc);
  assert.equal(doc.schema,"chernozerye.studio.release-notes");
  assert.equal(doc.formatVersion,1);
  assert.equal(doc.current.studio,"0.5.0");
  assert.equal(doc.current.game,"pre-alpha 0.5.5");
  assert.equal(doc.releases[0].version,doc.current.studio);
  assert.equal(doc.releases[0].area,"studio");
  assert.ok(doc.releases.length>=8);
  assert.ok(doc.roadmap.length>=6);
});
test("every historical release has concrete changes and verified commit references",()=>{
  const areas=new Set(doc.releases.map(x=>x.area));
  for(const area of ["studio","game","model","quest","forge"])assert.ok(areas.has(area),area);
  const github=new Set(doc.releases.flatMap(x=>x.commits.map(s=>s.slice(0,8))));
  for(const sha of ["e03944d1","2c369207","dd3e5530","a63d58ce","e44b0b7d","47384da1","042f3f5b"]){
    assert.ok(github.has(sha),"Missing verified release "+sha);
  }
  assert.ok(doc.releases.every(release=>release.changes.length>=2));
});
test("release filters and stable roadmap groupings",()=>{
  const total=R.filteredReleases(doc);
  const labs=R.filteredReleases(doc,"tools");
  assert.equal(total.length,doc.releases.length);
  assert.ok(labs.length>2);
  assert.ok(labs.every(x=>!["studio","game"].includes(x.area)));
  assert.ok(R.filteredReleases(doc,"studio").every(x=>x.area==="studio"));
  assert.ok(R.filteredReleases(doc,"game").every(x=>x.area==="game"));
  const grouped=Object.keys(R.PHASES).flatMap(x=>R.backlogByPhase(doc,x));
  assert.deepEqual(new Set(grouped.map(x=>x.id)),new Set(doc.roadmap.map(x=>x.id)));
  assert.ok(R.backlogByPhase(doc,"next").length>=2);
});
test("schema refuses duplicated releases, bad links and fake roadmap statuses",()=>{
  const copy=()=>structuredClone(doc);
  const duplicate=copy();
  duplicate.releases.push(duplicate.releases[1]);
  assert.throws(()=>R.normalize(duplicate),/Повторный/);
  const brokenSha=copy();
  brokenSha.releases[1].commits=["https://example.com"];
  assert.throws(()=>R.normalize(brokenSha),/SHA/);
  const brokenPhase=copy();
  brokenPhase.roadmap[0].phase="shipped";
  assert.throws(()=>R.normalize(brokenPhase),/стадия/);
  const changedVersion=copy();
  changedVersion.current.studio="99";
  assert.throws(()=>R.normalize(changedVersion),/Первая запись/);
  assert.equal(R.shortSha("<script>"),null);
});
