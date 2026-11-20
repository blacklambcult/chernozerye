/* CHERNOZERYE STUDIO release registry 0.4 — static, reviewed product metadata. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.ChernoReleaseCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const SCHEMA = "chernozerye.studio.release-notes";
  const AREAS = Object.freeze({all:"Все",studio:"STUDIO",game:"ИГРА",geo:"GEO LAB",quest:"QUEST LAB",model:"MODEL LAB",forge:"HELLISH FORGE"});
  const PHASES = Object.freeze({next:"СЛЕДУЮЩИЕ",planned:"В ПЛАНЕ",ideas:"ИДЕИ"});
  const PRIORITIES = Object.freeze({high:"ВЫСОКИЙ",medium:"СРЕДНИЙ",low:"НИЗКИЙ"});
  const SHA_PATTERN = /^[a-f0-9]{8}([a-f0-9]{32})?$/;
  const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
  function nonEmpty(value,label,max=500) {
    if(typeof value!=="string"||!value.trim()||value.length>max)throw Error("Некорректное поле "+label);
    return value.trim();
  }
  function checkDate(value,label) {
    const date=nonEmpty(value,label,10);
    if(!DATE_PATTERN.test(date)||Number.isNaN(Date.parse(date+"T12:00:00Z"))||
       new Date(date+"T12:00:00Z").toISOString().slice(0,10)!==date) throw Error("Некорректная дата: "+label);
    return date;
  }
  function normalize(doc) {
    if(!doc||typeof doc!=="object"||Array.isArray(doc)||doc.schema!==SCHEMA||doc.formatVersion!==1)
      throw Error("Неподдерживаемый формат журнала Studio");
    const current=doc.current;
    if(!current||typeof current!=="object"||Array.isArray(current))throw Error("Нет текущей версии");
    for(const key of ["studio","game","channel","headline","description","project"])
      nonEmpty(current[key],"current."+key);
    checkDate(current.date,"current.date");
    if(!Array.isArray(doc.releases)||doc.releases.length<1||doc.releases.length>80)
      throw Error("Неверный список релизов");
    if(!Array.isArray(doc.roadmap)||doc.roadmap.length>120)
      throw Error("Неверный список задач");
    const seen=new Set();
    for(const release of doc.releases) {
      if(!release||typeof release!=="object")throw Error("Повреждённый релиз");
      const id=nonEmpty(release.id,"release.id",80);
      if(seen.has("r:"+id))throw Error("Повторный релиз "+id);
      seen.add("r:"+id);
      nonEmpty(release.version,"release.version",30);
      nonEmpty(release.title,"release.title",160);
      if(!Object.hasOwn(AREAS,release.area)||release.area==="all")throw Error("Неизвестный модуль релиза");
      checkDate(release.date,"release.date");
      if(!Array.isArray(release.changes)||release.changes.length<1||release.changes.length>12)
        throw Error("У релиза нет списка изменений");
      for(const change of release.changes)nonEmpty(change,"release.change",480);
      if(!Array.isArray(release.commits)||release.commits.length>8||
         release.commits.some(s=>typeof s!=="string"||!SHA_PATTERN.test(s)))throw Error("Некорректный Git SHA");
    }
    if(doc.releases[0].version!==current.studio||doc.releases[0].area!=="studio")
      throw Error("Первая запись должна описывать текущий релиз Studio");
    for(const item of doc.roadmap) {
      if(!item||typeof item!=="object")throw Error("Повреждена задача");
      const id=nonEmpty(item.id,"roadmap.id",80);
      if(seen.has("b:"+id))throw Error("Повторная задача "+id);
      seen.add("b:"+id);
      if(!Object.hasOwn(PHASES,item.phase))throw Error("Неизвестная стадия задачи");
      if(!Object.hasOwn(PRIORITIES,item.priority))throw Error("Неизвестный приоритет");
      if(!Object.hasOwn(AREAS,item.area)||item.area==="all")throw Error("Неизвестный модуль задачи");
      nonEmpty(item.title,"roadmap.title",180);
      nonEmpty(item.description,"roadmap.description",500);
      nonEmpty(item.deliverable,"roadmap.deliverable",300);
    }
    return doc;
  }
  function filteredReleases(doc,filter="all") {
    if(filter==="tools")return doc.releases.filter(x=>!["studio","game"].includes(x.area));
    if(!Object.hasOwn(AREAS,filter))filter="all";
    if(filter==="all")return doc.releases.slice();
    return doc.releases.filter(x=>x.area===filter);
  }
  function backlogByPhase(doc,phase) {
    return doc.roadmap.filter(item=>item.phase===phase);
  }
  function shortSha(value) {
    return typeof value==="string"&&SHA_PATTERN.test(value)?value.slice(0,8):null;
  }
  return Object.freeze({SCHEMA,AREAS,PHASES,PRIORITIES,normalize,filteredReleases,backlogByPhase,shortSha});
});
