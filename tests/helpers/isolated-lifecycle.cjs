const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const [modulePath,configPath]=process.argv.slice(2);
const source=fs.readFileSync(modulePath,'utf8').replace(/^export /gm,'');
async function launch(expected){
 let reads=0,init=0,natives=0,closed=0,current='Bing';const observers=new Map(),timers=new Set();
 const config=fs.readFileSync(configPath,'utf8');
 const search={init:async()=>{init++;},getDefault:async()=>({name:current}),getEngineByName:name=>({name}),CHANGE_REASON:{USER:0},setDefault:async e=>{current=e.name;}};
 const context={Services:{appinfo:{name:'Zen',processType:0,PROCESS_TYPE_DEFAULT:0},dirsvc:{get:()=>({path:'fixture',append(){}})},console:{logStringMessage(){}},obs:{addObserver:(o,k)=>observers.set(k,o),removeObserver:(_o,k)=>observers.delete(k)}},Components:{classes:{
 '@mozilla.org/file/local;1':{createInstance:()=>({fileSize:config.length,initWithPath(p){assert.equal(p,configPath);}})},
 '@mozilla.org/network/file-input-stream;1':{createInstance:()=>({init(){},close(){}})},
 '@mozilla.org/intl/converter-input-stream;1':{createInstance:()=>{let used=false;return {init(){},close(){},readString(_n,p){if(used)return 0;used=true;reads++;p.value=config;return config.length;}};}},
 },interfaces:{},results:{}},ChromeUtils:{generateQI(){},importESModule(uri){
 if(uri.includes('SearchService'))return {SearchService:search};if(uri.includes('ctypes'))return {ctypes:{}};
 if(uri.includes('ServiceRequest'))return {ServiceRequest:class{}};if(uri.includes('Timer'))return {setTimeout:fn=>{timers.add(fn);return fn;},clearTimeout:fn=>timers.delete(fn)};throw Error('unexpected import');
 }},makeNative:()=>{natives++;return {readSystem:()=>({flags:3,server:'127.0.0.1:7897'}),readProcesses:()=>[],close:()=>{closed++;}}}};
 vm.createContext(context);vm.runInContext(source,context);
 vm.runInContext('scope.PSSWindows.createNative=makeNative;scope.PSSMihomo.detectTun=async()=>scope.PSSState.state("disabled");',context);
 observers.get('browser-delayed-startup-finished').observe();await new Promise(setImmediate);
 assert.equal(context.getStatus(),expected);assert.equal(reads,1);
 if(expected==='disabled'){assert.equal(natives,0);assert.equal(init,0);assert.equal(timers.size,0);assert.equal(current,'Bing');}
 else {assert.equal(current,'Google');assert.equal(timers.size,1);assert.equal(init,1);}
 observers.get('quit-application-granted').observe();assert.equal(timers.size,0);assert.equal(observers.size,0);assert.equal(closed,expected==='disabled'?0:1);
}
(async()=>{
 await launch('disabled');
 const config=JSON.parse(fs.readFileSync(configPath,'utf8'));assert.equal(config.token,'');config.enabled=true;fs.writeFileSync(configPath,JSON.stringify(config));await launch('default:Google');
 config.enabled=false;fs.writeFileSync(configPath,JSON.stringify(config));await launch('disabled');
 console.log('PASS: fresh installed module disabled -> enabled -> persistent disabled across simulated restarts; no timers/native/search while disabled; quit cleans simulated resources');
})().catch(()=>{console.error('FAIL: isolated lifecycle assertions');process.exitCode=1;});
