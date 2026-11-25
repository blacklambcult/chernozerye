const {test}=require("node:test");
const assert=require("node:assert/strict");
const H=require("../site/studio/commit-history.js");
const sha="a".repeat(40),parent="b".repeat(40);
const item=(s,parents,title)=>({sha:s,date:"2026-11-25T11:00:00Z",parents,title,body:"Details"});
const doc=()=>({schema:"chernozerye.studio.commit-history",version:1,head:sha,entries:[item(sha,[parent],"Roadmap 3.0"),item(parent,[],"Initial")]});
test("accept full history and stable micro-version IDs",()=>{
  const d=doc();assert.equal(H.normalize(d),d);assert.equal(H.version(d.entries[0]),"DEV-aaaaaaaa");
  assert.equal(H.filter(d.entries,"ROADMAP").length,1);
  assert.equal(H.filter(d.entries,"DEV-bbbbbbbb")[0].sha,parent);
  assert.equal(H.filter(d.entries,"Details").length,2);
});
test("reject duplicated, incomplete and mismatched histories",()=>{
  let d=doc();d.entries.push(d.entries[0]);assert.throws(()=>H.normalize(d));
  d=doc();d.entries.pop();assert.throws(()=>H.normalize(d));
  d=doc();d.head=parent;assert.throws(()=>H.normalize(d));
  d=doc();d.entries[0].sha="javascript:alert(1)";assert.throws(()=>H.normalize(d));
});
