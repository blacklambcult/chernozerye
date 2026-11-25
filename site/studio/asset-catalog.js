/* Read-only catalog over ChernoObjectLibrary. No second database. */
(function(root,factory){
  const api=factory();
  if(typeof module==="object"&&module.exports)module.exports=api;
  else {root.ChernoAssetCatalog=api;api.mount(root);}
})(typeof globalThis!=="undefined"?globalThis:this,function(){
  "use strict";
  const txt=(x,fallback="")=>typeof x==="string"&&x.trim()?x.trim():fallback;
  function summarize(models,placements){
    if(!Array.isArray(models)||!Array.isArray(placements))throw Error("Некорректный ответ библиотеки");
    const usage=new Map();
    for(const p of placements)if(typeof p?.modelId==="string")usage.set(p.modelId,(usage.get(p.modelId)||0)+1);
    const seen=new Set();
    const items=[];
    for(const model of models){
      if(!model||typeof model.id!=="string"||!model.id||seen.has(model.id))continue;
      seen.add(model.id);
      items.push(Object.freeze({id:model.id,name:txt(model.name,"Без названия"),
        source:txt(model.source,"Не указан"),kind:txt(model.kind,"Модель"),
        size:Number.isFinite(model.blob?.size)&&model.blob.size>=0?model.blob.size:0,
        used:usage.get(model.id)||0,updatedAt:txt(model.updatedAt)}));
    }
    items.sort((a,b)=>a.name.localeCompare(b.name,"ru")||a.id.localeCompare(b.id));
    return {items,placements:placements.length,bytes:items.reduce((sum,m)=>sum+m.size,0),
      missing:placements.filter(p=>!seen.has(p?.modelId)).length};
  }
  function filter(items,{query="",source="",used=""}={}){
    const needle=String(query).trim().toLocaleLowerCase("ru");
    return items.filter(m=>(!source||m.source===source)&&
      (used==="yes"?m.used>0:used==="no"?m.used===0:true)&&
      (!needle||[m.name,m.id,m.source,m.kind].join(" ").toLocaleLowerCase("ru").includes(needle)));
  }
  function formatBytes(bytes){
    if(bytes<1024)return bytes+" Б";
    if(bytes<1048576)return (bytes/1024).toFixed(1)+" КБ";
    return (bytes/1048576).toFixed(1)+" МБ";
  }
  function mount(win){
    const doc=win.document,$=id=>doc.getElementById(id);
    if(!$("asset-list"))return;
    let data=null,limit=40,request=0;
    const element=(tag,content,cls)=>{
      const e=doc.createElement(tag);if(cls)e.className=cls;
      e.textContent=content;return e;
    };
    function render(){
      if(!data)return;
      const filtered=filter(data.items,{query:$("asset-search").value,source:$("asset-source").value,used:$("asset-used").value});
      const cards=filtered.slice(0,limit).map(item=>{
        const card=element("article","","asset-card");
        card.append(element("h6",item.name),element("small",item.kind+" · "+item.source),
          element("code",item.id),element("small",formatBytes(item.size)),
          element("span","На карте: "+item.used,"asset-usage"));
        return card;
      });
      $("asset-list").replaceChildren(...cards);
      $("asset-more").hidden=filtered.length<=limit;
      $("asset-status").textContent="Найдено "+filtered.length+" из "+data.items.length+
        (data.missing?" · размещений без модели: "+data.missing:"")+
        (!filtered.length?" · нет подходящих моделей.":"");
    }
    async function refresh(){
      const serial=++request;
      $("asset-refresh").disabled=true;
      $("asset-status").textContent="Читаю локальную библиотеку…";
      try{
        const library=win.ChernoObjectLibrary;
        if(!library)throw Error("Хранилище не подключено");
        const [models,placements]=await Promise.all([library.models(),library.placements()]);
        if(serial!==request)return;
        data=summarize(models,placements);
        const selected=$("asset-source").value;
        const values=[...new Set(data.items.map(m=>m.source))].sort((a,b)=>a.localeCompare(b,"ru"));
        const options=["",...values].map(v=>{const e=element("option",v||"Все источники");e.value=v;return e;});
        $("asset-source").replaceChildren(...options);
        $("asset-source").value=values.includes(selected)?selected:"";
        $("asset-model-count").textContent=String(data.items.length);
        $("asset-placement-count").textContent=String(data.placements);
        $("asset-size").textContent=formatBytes(data.bytes);
        limit=40;render();
      }catch(error){
        if(serial!==request)return;
        data=null;$("asset-list").replaceChildren();$("asset-more").hidden=true;
        for(const id of ["asset-model-count","asset-placement-count","asset-size"])$(id).textContent="—";
        $("asset-status").textContent="Не удалось прочитать локальную библиотеку: "+String(error?.message||error);
      }finally{if(serial===request)$("asset-refresh").disabled=false;}
    }
    for(const id of ["asset-search","asset-source","asset-used"])$(id).addEventListener(id==="asset-search"?"input":"change",()=>{limit=40;render();});
    $("asset-more").addEventListener("click",()=>{limit+=40;render();});
    $("asset-refresh").addEventListener("click",refresh);
    win.ChernoAssetCatalogRefresh=refresh;
  }
  return Object.freeze({summarize,filter,formatBytes,mount});
});
