const {test}=require('node:test');const assert=require('node:assert/strict');
const {runReadonly}=require('../src/runtime/readonly.cjs');
const canary='fixture-only-private-canary';
function fixture(options={}){
  let requests=0,natives=0,closed=0;
  const args={loadedStatus:()=> 'disabled',readConfig:async()=>({enabled:false,token:canary}),
    requestFactory:()=>({request:async cfg=>{requests++;assert.equal(cfg.token,canary);return {status:200,text:'{"tun":{"enable":true}}'};},close:()=>closed++}),
    nativeFactory:()=>{natives++;return {readSystem:()=>({flags:3,server:'127.0.0.1:7897'}),readProcesses:()=>['verge-mihomo.exe'],close:()=>closed++};},...options};
  return {args,get requests(){return requests;},get natives(){return natives;},get closed(){return closed;}};
}
test('one-shot read-only reports states, releases resources, and excludes token',async()=>{
  const f=fixture();const report=await runReadonly(f.args);assert.equal(report.result,'pass');assert.equal(report.wouldUse,'Google');assert.equal(report.automaticSwitching,false);
  assert.equal(f.requests,1);assert.equal(f.natives,1);assert.equal(f.closed,2);assert(!JSON.stringify(report).includes(canary));
});
test('loader/config guards prevent API and native initialization',async()=>{
  for(const override of [{loadedStatus:()=> 'waiting'},{readConfig:async()=>({enabled:true,token:canary})},{readConfig:async()=>({enabled:false,token:''})},{readConfig:async()=>({enabled:false,token:canary,controllerUrl:'http://127.0.0.1:9999'})}]){
    const f=fixture(override);const report=await runReadonly(f.args);assert.equal(report.result,'stop');assert.equal(f.requests,0);assert.equal(f.natives,0);assert(!JSON.stringify(report).includes(canary));
  }
});
test('API authentication failure stops before Windows; response body never escapes',async()=>{
  const f=fixture({requestFactory:()=>({request:async()=>({status:401,text:canary}),close(){}})});
  const report=await runReadonly(f.args);assert.equal(report.stage,'api');assert.equal(report.reason,'api-authentication');assert.equal(f.natives,0);assert(!JSON.stringify(report).includes(canary));
});
test('unknown system and native exception stop without dumping exception details',async()=>{
  for(const readSystem of [()=>({flags:9}),()=>{throw new TypeError(canary);}]){
    const f=fixture({nativeFactory:()=>({readSystem,close(){}})});const report=await runReadonly(f.args);assert.equal(report.result,'stop');assert.equal(report.stage,'windows');assert(!JSON.stringify(report).includes(canary));
  }
});
