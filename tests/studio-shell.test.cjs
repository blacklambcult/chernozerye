const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const State=require("../site/studio/studio-state.js");
const dir=path.join(__dirname,"../site/studio");
const html=fs.readFileSync(path.join(dir,"index.html"),"utf8");
const source=fs.readFileSync(path.join(dir,"studio.js"),"utf8");
class Element {
  constructor(tag="div"){
    this.tag=tag;this.dataset={};this.events={};this.hidden=false;this.attrs={};this.children=[];this.classes=new Set();
    this.classList={toggle:(k,v)=>v?this.classes.add(k):this.classes.delete(k)};
    this.contentWindow={dispatchEvent:()=>{},location:{reload:()=>{}}};
  }
  addEventListener(k,fn){(this.events[k]??=[]).push(fn);}
  setAttribute(k,v){this.attrs[k]=v;}
  appendChild(e){this.children.push(e);}
  emit(k,e={}){for(const f of this.events[k]||[])f({preventDefault(){},...e});}
}
test("shell keeps one navigation per tool and all dashboard contracts",()=>{
  const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
  assert.equal(new Set(ids).size,ids.length);
  assert.deepEqual(new Set([...html.matchAll(/data-target="([^"]+)"/g)].map(m=>m[1])),new Set(State.TOOLS));
  assert.equal((html.match(/data-target="/g)||[]).length,State.TOOLS.length);
  assert.equal((html.match(/data-open="/g)||[]).length,0);
  for(const file of ["studio.js","studio-releases.js","commit-history.js","project-snapshot.js"]){
    const script=fs.readFileSync(path.join(dir,file),"utf8");
    for(const m of script.matchAll(/\$\("([^"]+)"\)|(?:getElementById|querySelector)\("#([a-z][a-z0-9-]+)"\)/g))
      assert.ok(ids.includes(m[1]||m[2]),file+": "+(m[1]||m[2]));
  }
});
test("repeated switches preserve iframe cache, storage and one rail event handler",()=>{
  const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
  const nodes=new Map(ids.map(id=>[id,new Element()]));
  const nav=State.TOOLS.map(id=>{const n=new Element("button");n.dataset.target=id;return n;});
  const tabs=["roadmap","history","data"].map(id=>{const n=new Element("button");n.dataset.dashboard=id;return n;});
  const panels=["roadmap","history","data"].map(id=>{const n=new Element();n.dataset.dashboardPanel=id;return n;});
  const selectors=new Map([".studio",".rail",".rail-toggle-text"].map(k=>[k,new Element()]));
  const document={getElementById:id=>nodes.get(id),querySelector:k=>selectors.get(k),querySelectorAll:k=>k==="[data-target]"?nav:k==="[data-dashboard]"?tabs:k==="[data-dashboard-panel]"?panels:[],createElement:t=>new Element(t)};
  const data=JSON.stringify({type:"FeatureCollection",features:[{}]});
  const store=new Map([[State.KEYS.geo,data]]);
  const storage={getItem:k=>store.get(k)??null,setItem:(k,v)=>store.set(k,v)};
  const win=new Element();const location={hash:"",href:"https://example.test/studio/",origin:"https://example.test"};
  Object.assign(win,{ChernoStudioState:State,location,localStorage:storage,requestAnimationFrame:fn=>fn()});
  const history={pushState:(_,__,hash)=>{location.hash=hash;location.href="https://example.test/studio/"+hash;}};
  new Function("window","document","localStorage","location","history","requestAnimationFrame","console",source)(win,document,storage,location,history,fn=>fn(),{info(){},warn(){}});
  for(const id of ["geo","quest","npc","home","quest","geo","home"])nav.find(x=>x.dataset.target===id).emit("click");
  assert.equal(nodes.get("rail-toggle").events.click.length,1);
  assert.equal(selectors.get(".rail").events.transitionend.length,1);
  assert.equal(nodes.get("editors").children.length,3);
  nodes.get("rail-toggle").emit("click");assert.ok(selectors.get(".studio").classes.has("nav-collapsed"));
  nodes.get("rail-toggle").emit("click");assert.ok(!selectors.get(".studio").classes.has("nav-collapsed"));
  tabs[2].emit("click");assert.deepEqual(panels.map(p=>p.hidden),[true,true,false]);
  assert.equal(nodes.get("geo-count").textContent,"1");
  tabs[1].emit("click");assert.deepEqual(panels.map(p=>p.hidden),[true,false,true]);
  assert.equal(store.get(State.KEYS.geo),data);
});
