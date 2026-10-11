const {test}=require('node:test'),assert=require('node:assert/strict');
const {state,validateConfig}=require('../src/core/state.cjs');
const {detectTun}=require('../src/core/mihomo.cjs');
const {createSwitcher}=require('../src/core/switcher.cjs');
function fixture(){
 const config=validateConfig({token:'fixture-only-not-a-real-key'});let current='Bing',system='disabled',mode='off';const writes=[],logs=[],timers=new Set();
 const request=async()=>{if(mode==='401')return {status:401,text:'fixture-only-not-a-real-key'};if(mode==='timeout')throw {code:'timeout'};if(mode==='live-refused'||mode==='absent-refused'||mode==='broken-snapshot')throw {code:'connection-refused'};return {status:200,text:JSON.stringify({tun:{enable:mode==='on'}})};};
 const processes=()=>{if(mode==='broken-snapshot')throw Error('private-native-detail');return mode==='live-refused'?['mihomo.exe']:[];};
 const search={init:async()=>{},getDefault:async()=>({name:current}),getEngineByName:name=>({name}),CHANGE_REASON:{USER:0},setDefault:async e=>{writes.push(e.name);current=e.name;}};
 const switcher=createSwitcher({config,search,detectSystem:()=>state(system),detectTun:()=>detectTun(config,request,processes),log:s=>logs.push(s),timers:{setTimeout:fn=>{timers.add(fn);return fn;},clearTimeout:fn=>timers.delete(fn)}});
 return {switcher,writes,logs,timers,set:(a,b)=>{system=a;mode=b;},manual:name=>{current=name;},get current(){return current;}};
}
test('authentication, timeout, GUI-only exit and failed snapshot hold unless system positively enabled; recovery resumes',async()=>{
 const f=fixture();await f.switcher.start();
 for(const mode of ['401','timeout','live-refused','broken-snapshot']){
  f.manual('Bing');f.set('disabled',mode);const before=f.writes.length;await f.switcher.tick();assert.equal(f.current,'Bing');assert.equal(f.writes.length,before);
  f.set('enabled',mode);await f.switcher.tick();assert.equal(f.current,'Google');
  f.set('disabled',mode);await f.switcher.tick();assert.equal(f.current,'Google');
 }
 f.set('disabled','absent-refused');await f.switcher.tick();assert.equal(f.current,'Bing');
 f.set('disabled','on');await f.switcher.tick();assert.equal(f.current,'Google');
 assert(!JSON.stringify(f.logs).includes('fixture-only'));f.switcher.stop();assert.equal(f.timers.size,0);
});
test('manual Google/Bing returns to managed target; third engine is preserved; stop suppresses future ticks',async()=>{
 const f=fixture();await f.switcher.start();f.manual('Google');await f.switcher.tick();assert.equal(f.current,'Bing');
 f.set('enabled','off');f.manual('Bing');await f.switcher.tick();assert.equal(f.current,'Google');
 f.manual('DuckDuckGo');const before=f.writes.length;await f.switcher.tick();assert.equal(f.current,'DuckDuckGo');assert.equal(f.writes.length,before);
 f.switcher.stop();f.manual('Bing');await f.switcher.tick();assert.equal(f.current,'Bing');assert.equal(f.timers.size,0);
});
