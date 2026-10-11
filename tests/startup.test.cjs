const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
test('global startup removes first-window observer; multiple windows keep one poller; quit cancels it',async()=>{
  const observers=new Map(),timers=new Map();let nextId=0,initializations=0,closed=0;
  const config=JSON.stringify({...JSON.parse(fs.readFileSync(path.join(__dirname,'../examples/config.example.json'),'utf8')),enabled:true});
  const search={init:async()=>{initializations++;},getDefault:async()=>({name:'Bing'}),getEngineByName:name=>({name}),setDefault:async()=>{},CHANGE_REASON:{USER:0}};
  const services={appinfo:{name:'Zen',processType:0,PROCESS_TYPE_DEFAULT:0},dirsvc:{get:()=>({path:'fixture',append(){}})},console:{logStringMessage(){}},obs:{addObserver:(o,k)=>observers.set(k,o),removeObserver:(o,k)=>{assert.equal(observers.get(k),o);observers.delete(k);}}};
  const context={Services:services,Components:{classes:{
    '@mozilla.org/file/local;1':{createInstance:()=>({fileSize:0,initWithPath(){},initWithFile(){},append(){}})},
    '@mozilla.org/network/file-input-stream;1':{createInstance:()=>({init(){},close(){}})},
    '@mozilla.org/intl/converter-input-stream;1':{createInstance:()=>{let read=false;return {init(){},close(){},readString(_n,part){if(read)return 0;read=true;part.value=config;return config.length;}};}},
  },interfaces:{},results:{}},ChromeUtils:{generateQI(){},importESModule(uri){
    if(uri.includes('SearchService'))return {SearchService:search};
    if(uri.includes('ctypes'))return {ctypes:{}};
    if(uri.includes('ServiceRequest'))return {ServiceRequest:class{}};
    if(uri.includes('Timer'))return {setTimeout:fn=>{timers.set(++nextId,fn);return nextId;},clearTimeout:id=>timers.delete(id)};
    throw Error('unexpected module '+uri);
  }}};
  vm.createContext(context);
  const source=fs.readFileSync(path.join(__dirname,'../dist/proxy-search-switcher.sys.mjs'),'utf8').replace(/^export /gm,'');
  vm.runInContext(source,context);
  vm.runInContext('scope.PSSWindows.createNative=()=>({readSystem:()=>({flags:1}),readProcesses:()=>[],close:()=>onClose()});scope.PSSMihomo.detectTun=async()=>scope.PSSState.state("disabled");',Object.assign(context,{onClose:()=>closed++}));
  assert.equal(observers.size,2);
  observers.get('browser-delayed-startup-finished').observe();
  assert.equal(observers.has('browser-delayed-startup-finished'),false);
  await new Promise(setImmediate);
  assert.equal(initializations,1);assert.equal(timers.size,1);
  // Further windows have no registered callback to duplicate initialization.
  for(let i=0;i<3;i++)observers.get('browser-delayed-startup-finished')?.observe();
  assert.equal(initializations,1);
  observers.get('quit-application-granted').observe();assert.equal(timers.size,0);assert.equal(closed,1);assert.equal(observers.size,0);
});
