const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");

const html=fs.readFileSync(path.join(__dirname,"../site/weapon-generator/index.html"),"utf8");
const inlineScripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
  .map(match=>match[1]).filter(Boolean);

test("procedural generator keeps all eight weapon classes and Godot sockets",()=>{
  for(const type of ["revolver","pistol","smg","assault","boltrifle","semirifle","doubleshotgun","pumpshotgun"])
    assert.match(html,new RegExp(`data-weapon="${type}"`));
  for(const socket of ["MuzzlePoint","EjectionPort","Weapon_Body"])
    assert.ok(html.includes(socket),socket);
  assert.ok(html.includes("QuaternionKeyframeTrack"));
});

test("Studio bridge exposes library and game delivery with editable specs",()=>{
  for(const field of ["name","damage","recoil","capacity","reload","sound","scale"])
    assert.match(html,new RegExp(`data-studio-field="${field}"`));
  assert.ok(html.includes('data-action="save-library"'));
  assert.ok(html.includes('data-action="send-game"'));
  assert.ok(html.includes("chernozerye.forge.game-model.v1"));
  assert.ok(html.includes("ChernoObjectLibrary"));
});

test("all inline JavaScript parses without modules or a build step",()=>{
  assert.equal(inlineScripts.length,1);
  for(const source of inlineScripts) assert.doesNotThrow(()=>new Function(source));
});
