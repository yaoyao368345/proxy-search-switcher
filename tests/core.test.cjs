const { test } = require('node:test');
const assert = require('node:assert/strict');
const { state, decide, classifySystem, validateConfig } = require('../src/core/state.cjs');
const { detectTun } = require('../src/core/mihomo.cjs');
const { createSwitcher } = require('../src/core/switcher.cjs');
const config = validateConfig({});
test('all nine three-state combinations', () => {
  for (const a of ['enabled','disabled','unknown']) for (const b of ['enabled','disabled','unknown']) {
    assert.equal(decide(state(a),state(b)), a === 'enabled' || b === 'enabled' ? 'Google' : a === 'disabled' && b === 'disabled' ? 'Bing' : null);
  }
});
test('manual, PAC, WPAD, foreign and protocol proxy distinctions', () => {
  for (const [snapshot, expected] of [
    [{flags:1},'disabled'],[{flags:3,server:'127.0.0.1:7897'},'enabled'],
    [{flags:3,server:'http=127.0.0.1:7897;https=127.0.0.1:7897'},'enabled'],
    [{flags:3,server:'http=127.0.0.1:7897'},'unknown'],
    [{flags:3,server:'http=127.0.0.1:7897;https=evil:7897'},'unknown'],
    [{flags:3,server:'127.0.0.1:9999'},'unknown'],[{flags:5,pac:'http://local/pac'},'unknown'],
    [{flags:9},'unknown'],[{flags:15,server:'127.0.0.1:7897'},'unknown'],
    [{flags:3,server:''},'unknown'],[{flags:0},'unknown'],[null,'unknown'],
    [{flags:3,server:'http=127.0.0.1:7897;http=127.0.0.1:7897;https=127.0.0.1:7897'},'unknown'],
  ]) assert.equal(classifySystem(snapshot,config).state,expected);
});
test('config rejects remote credentials and invalid settings', () => {
  for (const controllerUrl of ['http://localhost:9097','http://example.com','http://127.0.0.1:9097@evil','http://127.0.0.1:9097/path','http://127.0.0.1:99999']) assert.throws(() => validateConfig({controllerUrl}));
  for (const raw of [{intervalMs:0},{timeoutMs:NaN},{token:'a\nb'},{enabled:'yes'},{coreProcessNames:[]},{systemProxyServers:['proxy.example:7897']}]) assert.throws(() => validateConfig(raw));
});
test('TUN boolean, HTTP, malformed and absent JSON', async () => {
  for (const [response,expected] of [
    [{status:200,text:'{"tun":{"enable":true}}'},'enabled'],
    [{status:200,text:'{"tun":{"enable":false}}'},'disabled'],
    [{status:401,text:'secret'},'unknown'],[{status:503,text:''},'unknown'],
    [{status:200,text:'{'},'unknown'],[{status:200,text:'{"tun":{"enable":"false"}}'},'unknown'],
  ]) assert.equal((await detectTun(config,async()=>response,()=>[])).state,expected);
});
test('only connection refusal PLUS absent core can prove shutdown', async () => {
  for (const [code,processes,expected] of [
    ['timeout',[],'unknown'],['network',[],'unknown'],['connection-refused',[],'disabled'],
    ['connection-refused',['verge-mihomo.exe'],'unknown'],['connection-refused',null,'unknown'],
  ]) assert.equal((await detectTun(config,async()=>{throw {code};},()=>processes)).state,expected);
  assert.equal((await detectTun(config,async()=>{throw {code:'connection-refused'};},()=>{throw Error();})).state,'unknown');
});
function fixture(overrides={}) {
  let name='Bing',calls=[],queue=[],logs=[];
  const search={init:async()=>{},getDefault:async()=>({name}),getEngineByName:name=>({name}),CHANGE_REASON:{USER:7},setDefault:async(e,r)=>{calls.push([e.name,r]);name=e.name;}};
  const switcher=createSwitcher({config,search,timers:{setTimeout:fn=>{queue.push(fn);return fn;},clearTimeout:fn=>{queue=queue.filter(v=>v!==fn);}},detectSystem:async()=>state('enabled'),detectTun:async()=>state('unknown'),log:v=>logs.push(v),...overrides});
  return {switcher,search,calls,logs,setName:v=>name=v,get queue(){return queue;}};
}
test('immediate switch, correct reason, no redundant writes or duplicate start', async()=>{
  const f=fixture();await f.switcher.start();await f.switcher.start();assert.deepEqual(f.calls,[['Google',7]]);assert.equal(f.queue.length,1);
  const fn=f.queue.shift();fn();await f.switcher.tick();assert.equal(f.calls.length,1);assert.equal(f.queue.length,1);assert.equal(f.logs.length,1);f.switcher.stop();assert.equal(f.queue.length,0);
});
test('unknown preserves current, Bing when both off, third engine preserved',async()=>{
  const f=fixture({detectSystem:async()=>state('disabled'),detectTun:async()=>state('disabled')});f.setName('Google');await f.switcher.start();assert.equal(f.calls[0][0],'Bing');f.switcher.stop();
  const g=fixture();g.setName('DuckDuckGo');await g.switcher.start();assert.equal(g.calls.length,0);g.switcher.stop();
  const h=fixture({detectSystem:async()=>state('unknown')});await h.switcher.start();assert.equal(h.calls.length,0);h.switcher.stop();
});
test('concurrent ticks share request; stop suppresses an in-flight switch',async()=>{
  let release, count=0;const gate=new Promise(r=>release=r);
  const f=fixture({detectTun:async()=>{count++;await gate;return state('disabled');}});
  const starting=f.switcher.start();await new Promise(setImmediate);const a=f.switcher.tick(),b=f.switcher.tick();assert.equal(a,b);assert.equal(count,1);f.switcher.stop();release();await starting;assert.equal(f.calls.length,0);assert.equal(f.queue.length,0);
});
test('missing engines and search init errors fail safely',async()=>{
  const f=fixture();f.search.getEngineByName=()=>null;await f.switcher.start();assert.equal(f.calls.length,0);assert.equal(f.queue.length,0);
  const g=fixture();g.search.init=async()=>{throw Error('private failure');};await g.switcher.start();assert.equal(g.queue.length,0);assert.deepEqual(g.logs,['stopped:search-incompatible']);
});
test('user change while getDefault awaits cancels pending write',async()=>{
  const f=fixture();let reads=0;f.search.getDefault=async()=>({name:++reads===1?'Bing':'DuckDuckGo'});await f.switcher.start();assert.equal(f.calls.length,0);f.switcher.stop();
});
