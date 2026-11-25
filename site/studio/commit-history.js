/* Build-scoped micro-version history; no live GitHub API or credentials. */
(function(root,factory){
  const api=factory();
  if(typeof module==="object"&&module.exports)module.exports=api;
  else api.mount(root.document,root.fetch.bind(root));
})(globalThis,function(){
  "use strict";
  const SHA=/^[a-f0-9]{40}$/;
  const BASE="https://github.com/blacklambcult/chernozerye/commit/";
  const PAGE=30;
  function normalize(doc){
    if(!doc||doc.schema!=="chernozerye.studio.commit-history"||doc.version!==1||!SHA.test(doc.head)||!Array.isArray(doc.entries)||!doc.entries.length||doc.entries[0].sha!==doc.head)throw Error("Invalid commit history");
    const seen=new Set();
    for(const item of doc.entries){
      if(!item||!SHA.test(item.sha)||seen.has(item.sha)||typeof item.title!=="string"||typeof item.body!=="string"||typeof item.date!=="string"||!Number.isFinite(Date.parse(item.date))||!Array.isArray(item.parents)||item.parents.some(p=>!SHA.test(p)))throw Error("Invalid commit entry");
      seen.add(item.sha);
    }
    if(doc.entries.some(item=>item.parents.some(p=>!seen.has(p))))throw Error("Incomplete history");
    return doc;
  }
  function version(item){return "DEV-"+item.sha.slice(0,8);}
  function filter(entries,query){
    const q=String(query).trim().toLowerCase();
    return q?entries.filter(x=>[version(x),x.sha,x.date,x.title,x.body].some(s=>s.toLowerCase().includes(q))):entries;
  }
  function mount(document,fetch){
    const $=id=>document.getElementById(id);
    const micro=$("micro-history"),archive=$("release-archive"),list=$("micro-list");
    if(!micro||!archive||!list)return;
    let entries=[],limit=PAGE,loaded=false;
    function mode(showMicro){
      micro.hidden=!showMicro;archive.hidden=showMicro;
      $("history-mode-micro").setAttribute("aria-pressed",String(showMicro));
      $("history-mode-releases").setAttribute("aria-pressed",String(!showMicro));
      $("history-mode-micro").classList.toggle("active",showMicro);
      $("history-mode-releases").classList.toggle("active",!showMicro);
    }
    function element(tag,cls,text){
      const node=document.createElement(tag);
      if(cls)node.className=cls;
      if(text!==undefined)node.textContent=text;
      return node;
    }
    function paint(){
      if(!loaded)return;
      const matched=filter(entries,$("micro-search").value);
      $("micro-count").textContent=matched.length+" / "+entries.length+" КОММИТОВ";
      list.replaceChildren();
      if(!matched.length)list.append(element("p","release-loading","Нет совпадений."));
      for(const item of matched.slice(0,limit)){
        const detail=element("details","release-item");
        const summary=element("summary");
        const heading=element("span","release-item-heading");
        const main=element("span","release-main-info");
        main.append(element("span","release-caret","›"),element("span","release-label",version(item)),element("span","release-area",item.parents.length>1?"MERGE":"COMMIT"));
        heading.append(main,element("span","release-date",new Date(item.date).toLocaleString("ru-RU",{timeZone:"Europe/Moscow",day:"2-digit",month:"2-digit",year:"2-digit",hour:"2-digit",minute:"2-digit"})));
        summary.append(heading,element("span","release-item-title",item.title));
        const body=element("div","release-detail");
        if(item.body)body.append(element("p","micro-body",item.body));
        const links=element("div","release-commits");
        const link=element("a","",item.sha.slice(0,12)+" ↗");
        link.href=BASE+item.sha;link.target="_blank";link.rel="noopener noreferrer";
        links.append(link);body.append(links);detail.append(summary,body);list.append(detail);
      }
      $("micro-more").hidden=limit>=matched.length;
    }
    $("history-mode-micro").addEventListener("click",()=>mode(true));
    $("history-mode-releases").addEventListener("click",()=>mode(false));
    $("micro-search").addEventListener("input",()=>{limit=PAGE;paint();list.scrollTop=0;});
    $("micro-more").addEventListener("click",()=>{limit+=PAGE;const top=list.scrollTop;paint();list.scrollTop=top;});
    mode(true);
    (async()=>{
      try{
        const [response,meta]=await Promise.all([fetch("./commit-history.json",{cache:"no-store"}),fetch("./build-meta.json",{cache:"no-store"})]);
        if(!response.ok||!meta.ok)throw Error("Build history unavailable");
        const data=normalize(await response.json());
        if((await meta.json()).commit!==data.head)throw Error("History/build mismatch");
        entries=data.entries;loaded=true;paint();
      }catch(error){
        list.replaceChildren(element("p","release-loading","Журнал этой сборки недоступен. История GitHub доступна по ссылке ниже; крупные релизы сохранены."));
        $("micro-count").textContent="НЕТ ДАННЫХ";
      }
    })();
  }
  return {normalize,version,filter,mount};
});
