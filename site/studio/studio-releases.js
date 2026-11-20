/* CHERNOZERYE STUDIO / Release Desk: read-only changelog and roadmap. */
(() => {
  "use strict";
  const Core=window.ChernoReleaseCore;
  if(!Core)throw Error("Release Desk core missing");
  const $=(id)=>document.getElementById(id);
  const escaped=(value)=>String(value).replace(/[&<>"']/g,c=>({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
  }[c]));
  const gitBase="https://github.com/blacklambcult/chernozerye/commit/";
  const humanDate=(iso)=>{
    if(typeof iso!=="string"||!/^\d{4}-\d{2}-\d{2}$/.test(iso))return "—";
    const [year,month,day]=iso.split("-");
    return day+"."+month+"."+year;
  };
  let documentData=null;
  let filter="all";

  function paintReleases() {
    if(!documentData)return;
    const list=Core.filteredReleases(documentData,filter);
    $("release-count").textContent=list.length+" ВЕРСИЙ";
    if(!list.length){
      $("release-list").innerHTML='<p class="release-loading">По этому разделу пока нет записей.</p>';
      return;
    }
    $("release-list").innerHTML=list.map((release,index)=>{
      const label=Core.AREAS[release.area]||"МОДУЛЬ";
      const changes=release.changes.map(text=>"<li>"+escaped(text)+"</li>").join("");
      const commits=release.commits.length ?
        '<div class="release-commits"><span>КОММИТЫ</span>'+
          release.commits.map(sha=>'<a href="'+gitBase+sha+'" target="_blank" rel="noopener noreferrer" title="Открыть коммит на GitHub">'+
            escaped(Core.shortSha(sha))+" ↗</a>").join("")+"</div>" : "";
      return '<details class="release-item" '+(index===0?"open":"")+'><summary>'+
        '<span class="release-item-heading"><span class="release-main-info">'+
        '<span class="release-caret" aria-hidden="true">›</span>'+
        '<span class="release-label">V '+escaped(release.version)+'</span>'+
        '<span class="release-area">'+escaped(label)+'</span></span>'+
        '<span class="release-date">'+humanDate(release.date)+'</span></span>'+
        '<span class="release-item-title">'+escaped(release.title)+'</span></summary>'+
        '<div class="release-detail"><ul>'+changes+'</ul>'+commits+'</div></details>';
    }).join("");
  }

  function paintRoadmap() {
    if(!documentData)return;
    $("roadmap-count").textContent=documentData.roadmap.length+" ЗАДАЧ";
    let serial=0;
    $("roadmap-list").innerHTML=Object.entries(Core.PHASES).map(([phase,label])=>{
      const items=Core.backlogByPhase(documentData,phase);
      if(!items.length)return "";
      const rows=items.map(item=>{
        serial++;
        return '<article class="roadmap-card" data-roadmap-id="'+escaped(item.id)+'">'+
          '<div class="roadmap-card-title"><span class="roadmap-marker">'+
          String(serial).padStart(2,"0")+'</span><strong>'+escaped(item.title)+'</strong></div>'+
          '<p>'+escaped(item.description)+'</p>'+
          '<div class="roadmap-meta"><span>'+escaped(Core.AREAS[item.area])+'</span>'+
          '<span>ПРИОРИТЕТ / '+escaped(Core.PRIORITIES[item.priority])+'</span></div>'+
          '<div class="roadmap-output">РЕЗУЛЬТАТ: '+escaped(item.deliverable)+'</div>'+
          '</article>';
      }).join("");
      return '<section class="roadmap-phase" aria-label="'+escaped(label)+'">'+
        '<div class="roadmap-phase-head"><strong>◈ '+escaped(label)+'</strong>'+
        '<small>'+items.length+' ПУНКТ.</small></div>'+rows+'</section>';
    }).join("");
  }
  function fillCurrent() {
    if(!documentData)return;
    const info=documentData.current;
    $("release-current-version").textContent="STUDIO "+info.studio;
    $("studio-version-top").textContent="STUDIO "+info.studio;
    $("release-current-title").textContent=info.headline;
    $("release-current-description").textContent=info.description;
    $("release-current-date").textContent=humanDate(info.date);
    $("release-game-version").textContent=info.game.toUpperCase();
  }
  async function loadBuildMetadata() {
    try {
      const response=await fetch("./build-meta.json",{cache:"no-store"});
      if(!response.ok)throw Error("Build metadata not available");
      const info=await response.json();
      const sha=typeof info.commit==="string"?info.commit:"";
      if(!/^[a-f0-9]{40}$/.test(sha))throw Error("Invalid build commit");
      const short=Core.shortSha(sha);
      $("release-build-sha").textContent=short+" ↗";
      $("release-build-sha").href=gitBase+sha;
      $("release-build-sha").title="Коммит опубликованной сборки: "+sha;
    }catch(err){
      // Local static preview is allowed; the actual GitHub Pages workflow
      // always emits an exact-SHA build-meta.json file.
      $("release-build-sha").textContent="ОТКРЫТЬ GIT ↗";
      $("release-build-sha").href="https://github.com/blacklambcult/chernozerye/commits/main/";
    }
  }
  function setFilter(value) {
    if(value!=="tools"&&!Object.hasOwn(Core.AREAS,value))return;
    filter=value;
    for(const button of document.querySelectorAll("[data-changelog-filter]")){
      const active=button.dataset.changelogFilter===filter;
      button.classList.toggle("active",active);
      button.setAttribute("aria-pressed",String(active));
    }
    paintReleases();
  }
  for(const button of document.querySelectorAll("[data-changelog-filter]")){
    button.addEventListener("click",()=>setFilter(button.dataset.changelogFilter));
  }
  async function initialize() {
    try {
      const response=await fetch("./releases.json",{cache:"no-store"});
      if(!response.ok)throw Error("HTTP "+response.status);
      documentData=Core.normalize(await response.json());
      fillCurrent();
      paintReleases();
      paintRoadmap();
      console.info("STUDIO_RELEASE_DESK_READY: current="+documentData.current.studio+
        " releases="+documentData.releases.length+" roadmap="+documentData.roadmap.length);
    }catch(error){
      console.error("STUDIO_RELEASE_DESK_ERROR",error);
      const fallback='Не удалось загрузить журнал обновлений. '+
        'Можно проверить историю проекта через ссылку «ИСТОРИЯ GIT».';
      $("release-list").textContent=fallback;
      $("roadmap-list").textContent="Роадмап временно недоступен.";
      $("release-count").textContent="НЕТ ДАННЫХ";
      $("roadmap-count").textContent="НЕТ ДАННЫХ";
    }
    await loadBuildMetadata();
  }
  void initialize();
})();
