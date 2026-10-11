const {test}=require('node:test');const assert=require('node:assert/strict');
const {classifySystem,decide,validateConfig}=require('../src/core/state.cjs');
const {detectTun}=require('../src/core/mihomo.cjs');
const {createSwitcher}=require('../src/core/switcher.cjs');
const {createNative}=require('../src/platform/windows/native.cjs');
const {fakeCtypes}=require('./helpers/fake-ctypes.cjs');
const config=validateConfig({});
test('disabled manual flag wins over retained matching, foreign, and protocol endpoints',()=>{
  for(const server of ['127.0.0.1:7897','http=127.0.0.1:7897;https=127.0.0.1:7897','foreign.example:1234','']){
    assert.deepEqual(classifySystem({flags:1,server},config),{state:'disabled',reason:'manual-proxy-off'});
  }
  assert.equal(classifySystem({flags:3,server:'127.0.0.1:7897'},config).state,'enabled');
  assert.equal(classifySystem({flags:3,server:'foreign.example:1234'},config).state,'unknown');
});
test('retained endpoint OR TUN keeps the required three-state truth table',()=>{
  const off=classifySystem({flags:1,server:'127.0.0.1:7897'},config);
  assert.equal(decide(off,{state:'disabled'}),'Bing');assert.equal(decide(off,{state:'enabled'}),'Google');assert.equal(decide(off,{state:'unknown'}),null);
});
test('WinINet-to-controller integration covers four combinations, retained endpoint and API unknown',async()=>{
  let manual=false,tun=false,apiStatus=200,name='Bing';const writes=[],timers=new Map();let timerId=0;
  const fake=fakeCtypes({onQuery:({item,string})=>{item.value=item.option===10?(manual?3:1):string(item.option===2?'127.0.0.1:7897':'');return 1;}});
  const native=createNative(fake.c,'C:\\Windows\\System32');
  const search={init:async()=>{},getDefault:async()=>({name}),getEngineByName:name=>({name}),CHANGE_REASON:{USER:0},setDefault:async engine=>{writes.push(engine.name);name=engine.name;}};
  const controller=createSwitcher({config,search,timers:{setTimeout:fn=>{timers.set(++timerId,fn);return timerId;},clearTimeout:id=>timers.delete(id)},
    detectSystem:()=>classifySystem(native.readSystem(),config),
    detectTun:()=>detectTun(config,async()=>({status:apiStatus,text:JSON.stringify({tun:{enable:tun}})}),()=>null)});
  try{
    await controller.start();assert.equal(name,'Bing');
    for(const [sys,nextTun,expected]of [[true,false,'Google'],[true,true,'Google'],[false,true,'Google'],[false,false,'Bing']]){
      manual=sys;tun=nextTun;await controller.tick();assert.equal(name,expected);assert.equal(timers.size,1);
    }
    manual=true;await controller.tick();assert.equal(name,'Google');manual=false;apiStatus=401;await controller.tick();assert.equal(name,'Google');
    assert.deepEqual(writes,['Google','Bing','Google']);
  }finally{controller.stop();native.close();}
  assert.equal(timers.size,0);assert.equal(fake.closed.length,3);
});
