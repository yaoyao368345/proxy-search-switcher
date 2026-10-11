const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
function fixture(configText,options={}){
  const observers=new Map(),imports=[],messages=[];let reads=0;
  const context={Services:{appinfo:{name:'Zen',processType:0,PROCESS_TYPE_DEFAULT:0},dirsvc:{get:()=>({})},console:{logStringMessage:v=>messages.push(v)},obs:{addObserver:(o,k)=>observers.set(k,o),removeObserver:(o,k)=>{assert.equal(observers.get(k),o);observers.delete(k);}}},Components:{classes:{
    '@mozilla.org/file/local;1':{createInstance:()=>({fileSize:100,initWithPath(){},initWithFile(){},append(){}})},
    '@mozilla.org/network/file-input-stream;1':{createInstance:()=>({init(){if(options.readFails)throw Error('fixture-secret-detail');},close(){}})},
    '@mozilla.org/intl/converter-input-stream;1':{createInstance:()=>{let consumed=false;return {init(){},close(){},readString(_n,out){if(consumed)return 0;consumed=true;reads++;out.value=configText;return configText.length;}};}},
  },interfaces:{},results:{}},ChromeUtils:{importESModule(uri){imports.push(uri);throw Error('unexpected initialization of capability');}}};
  vm.createContext(context);
  const built=fs.readFileSync(path.join(__dirname,'../dist/proxy-search-switcher.sys.mjs'),'utf8').replace(/^export /gm,'');
  vm.runInContext(built,context);
  return {context,observers,imports,messages,get reads(){return reads;},fire:()=>observers.get('browser-delayed-startup-finished')?.observe()};
}
test('import executes entry but waits for startup event before reading config',()=>{
  const f=fixture('{"enabled":false}');assert.equal(f.context.getStatus(),'waiting');assert.equal(f.reads,0);assert.equal(f.observers.size,2);
});
test('disabled means successful config validation; no detector or timers are constructed',async()=>{
  const f=fixture('{"enabled":false,"token":"fixture-secret-detail"}');f.fire();await new Promise(setImmediate);
  assert.equal(f.context.getStatus(),'disabled');assert.equal(f.reads,1);assert.equal(f.imports.length,0);assert.equal(f.messages.length,0);assert(!f.observers.has('browser-delayed-startup-finished'));assert(f.observers.has('quit-application-granted'));
});
test('malformed and invalid config are blocked, never called disabled',async()=>{
  for(const text of ['{','{"enabled":"false"}','{"enabled":false,"timeoutMs":0}']){
    const f=fixture(text);f.fire();await new Promise(setImmediate);assert.equal(f.context.getStatus(),'blocked:capability-or-config');assert.equal(f.imports.length,0);
  }
});
test('config read failure is blocked and does not log sensitive exception details',async()=>{
  const f=fixture('{"enabled":false}',{readFails:true});f.fire();await new Promise(setImmediate);assert.equal(f.context.getStatus(),'blocked:capability-or-config');assert(!JSON.stringify(f.messages).includes('fixture-secret-detail'));
});
test('quit before first window prevents background initialization',()=>{
  const f=fixture('{"enabled":false}');f.observers.get('quit-application-granted').observe();f.fire();assert.equal(f.context.getStatus(),'stopped');assert.equal(f.reads,0);assert.equal(f.observers.size,0);
});
