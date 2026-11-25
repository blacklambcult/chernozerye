const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs"),os=require("node:os"),path=require("node:path");
const {execFileSync}=require("node:child_process");
const root=path.join(__dirname,"..");
const read=p=>fs.readFileSync(path.join(root,p),"utf8");
const folders=["building-generator","nature-generator","arms","weapon-generator"];
const css=read("site/studio/generator-workbench.css");
test("generators share side-panel presentation and render at the canvas size",()=>{
  for(const folder of folders){
    const html=read("site/"+folder+"/index.html");
    assert.match(html,/class="generator-workbench/);
    assert.ok(html.includes("../studio/generator-workbench.css?v=1"));
    assert.match(html,/const w = Math.max\(1, canvas.clientWidth \|\| window.innerWidth\)/);
    assert.match(html,/const h = Math.max\(1, canvas.clientHeight \|\| window.innerHeight\)/);
    assert.match(html,/const cw = canvas.clientWidth/);
  }
  assert.match(css,/inset:0 var\(--gen-right-inset\) var\(--gen-bottom\) var\(--gen-left-inset\)/);
  assert.match(css,/\.generator-workbench\.ui-hidden\{--gen-left-inset:0px;--gen-right-inset:0px/);
});
function findChrome(){
  for(const name of [process.env.CHROME_BIN,"google-chrome","google-chrome-stable","chromium","chromium-browser"].filter(Boolean)){
    try{execFileSync(name,["--version"],{stdio:"ignore"});return name;}catch{}
  }
  return null;
}
const chrome=findChrome();
test("actual generator DOM reserves a non-overlapping preview at desktop and narrow sizes",{skip:!chrome&&"Chromium unavailable"},()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),"generator-layout-"));
  try{
    for(const folder of folders){
      let html=read("site/"+folder+"/index.html")
        .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,"")
        .replace('<link rel="stylesheet" href="../studio/generator-workbench.css?v=1">',"<style>"+css+"</style>");
      const check=`<script>
      try{
        const body=document.body,viewport=document.getElementById("viewport"),hud=document.getElementById("hud");
        const library=document.getElementById("library-workspace");
        document.getElementById("drawer").classList.remove("collapsed");
        const rect=e=>e.getBoundingClientRect();
        const disjoint=(a,b)=>a.right<=b.left+1||b.right<=a.left+1||a.bottom<=b.top+1||b.bottom<=a.top+1;
        const v=rect(viewport);
        if(v.width<100||v.height<100)throw Error("preview too small");
        for(const e of [hud.querySelector(".top-stack"),hud.querySelector(".bottom-stack"),library].filter(Boolean)){
          const r=rect(e);
          if(r.width<50||r.height<20||!disjoint(v,r))throw Error("panel overlaps preview: "+e.className);
          if(r.left< -1||r.right>innerWidth+1||r.top< -1||r.bottom>innerHeight+1)throw Error("panel outside window: "+(e.id||e.className)+" "+[r.left,r.top,r.right,r.bottom].join(",")+" / "+innerWidth+"x"+innerHeight);
        }
        body.classList.add("ui-hidden");
        if(getComputedStyle(hud).display!=="none")throw Error("UI remains visible in fullscreen");
        const full=rect(viewport);
        if(Math.abs(full.width-innerWidth)>1||Math.abs(full.height-innerHeight)>1)throw Error("hidden UI does not restore viewport");
        body.dataset.layoutCheck="ok";
      }catch(error){document.body.dataset.layoutCheck="error: "+error.message;}
      </script>`;
      html=html.replace("</body>",check+"</body>");
      const file=path.join(dir,folder+".html");fs.writeFileSync(file,html);
      for(const size of ["1280,800","760,700"]){
        const dom=execFileSync(chrome,["--headless","--no-sandbox","--disable-dev-shm-usage","--disable-gpu","--no-first-run","--no-default-browser-check","--window-size="+size,"--dump-dom","file://"+file],{encoding:"utf8",timeout:30000,maxBuffer:8*1024*1024,stdio:["ignore","pipe","ignore"]});
        const status=dom.match(/<body[^>]*data-layout-check="([^"]+)"/i)?.[1];
        assert.equal(status,"ok",folder+" "+size+": "+status);
      }
    }
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
