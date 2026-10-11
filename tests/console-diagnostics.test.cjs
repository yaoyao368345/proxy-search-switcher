const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=name=>fs.readFileSync(path.join(__dirname,'../examples/diagnostics/'+name+'.js'),'utf8');
test('loader probe never imports a project module not loaded by fx-autoconfig',()=>{
  for(const running of [false,true]){
    let imports=0;const context={ChromeUtils:{importESModule(uri){if(uri.includes('uc_api'))return {Runtime:{loaderVersion:'0.10.16'},Scripts:{getScriptData:()=>({isRunning:running,chromeURI:'chrome://userscripts/content/proxy-search-switcher.sys.mjs'})}};imports++;return {getStatus:()=> 'disabled'};}}};
    const result=JSON.parse(vm.runInNewContext(source('01-loader'),context));assert.equal(imports,running?1:0);assert.equal(result.configValidatedAtStartup,running);
  }
});
function apiFixture(config,send){
  const canary='fixture-token-must-not-appear';config={enabled:false,token:canary,controllerUrl:'http://127.0.0.1:9097',...config};
  const text=JSON.stringify(config);let requests=0,aborts=0,instance;
  class Request{
    constructor(){instance=this;this.bypassProxy=true;this.channel={};}
    open(method,url,opts){assert.equal(method,'GET');assert.equal(url,'http://127.0.0.1:9097/configs');assert.equal(opts.bypassProxy,true);}
    setRequestHeader(name,value){assert.equal(name,'Authorization');assert.equal(value,'Bearer '+canary);}
    send(){requests++;send(this,canary);}
    abort(){aborts++;this.onabort?.();}
  }
  const context={Services:{dirsvc:{get:()=>({clone:()=>({fileSize:text.length,append(){}})})}},Components:{classes:{
    '@mozilla.org/network/file-input-stream;1':{createInstance:()=>({init(){},close(){}})},
    '@mozilla.org/intl/converter-input-stream;1':{createInstance:()=>{let consumed=false;return {init(){},close(){},readString(_n,out){if(consumed)return 0;consumed=true;out.value=text;return text.length;}};}},
  },interfaces:{},results:{NS_ERROR_ABORT:1}},ChromeUtils:{generateQI:()=>function(){return this;},importESModule:()=>({ServiceRequest:Request})}};
  return {context,canary,get requests(){return requests;},get aborts(){return aborts;},get instance(){return instance;}};
}
test('minimal API probe performs one request, returns only safe fields, cleans up',async()=>{
  const f=apiFixture({},(x,token)=>{x.status=200;x.responseText=JSON.stringify({tun:{enable:true},sensitive:token});x.onload();});
  const text=await vm.runInNewContext(source('02-api'),f.context);const result=JSON.parse(text);assert.equal(result.result,'pass');assert.equal(result.httpStatus,200);assert.equal(result.tunEnabled,true);assert.equal(f.requests,1);assert.equal(f.aborts,1);assert(!text.includes(f.canary));
});
test('minimal API config guard refuses enabled or remote controller without request',async()=>{
  for(const config of [{enabled:true},{controllerUrl:'http://example.com'},{token:''}]){
    const f=apiFixture(config,()=>{throw Error('must not request');});const result=JSON.parse(await vm.runInNewContext(source('02-api'),f.context));assert.equal(result.result,'stop');assert.equal(f.requests,0);
  }
});
test('API 401, timeout and redirect stop with sanitized output',async()=>{
  const scenarios=[
    (x,token)=>{x.status=401;x.responseText=token;x.onload();},
    x=>x.ontimeout(),
    x=>x.channel.notificationCallbacks.asyncOnChannelRedirect(null,null,0,{onRedirectVerifyCallback:code=>assert.equal(code,1)}),
  ];
  for(const send of scenarios){const f=apiFixture({},send);const text=await vm.runInNewContext(source('02-api'),f.context);assert.equal(JSON.parse(text).result,'stop');assert(!text.includes(f.canary));}
});
test('native console probe rejects unverified ABI without opening DLLs',()=>{
  let opens=0;const context={ChromeUtils:{importESModule:()=>({ctypes:{voidptr_t:{size:4},open:()=>opens++}})}};
  const result=JSON.parse(vm.runInNewContext(source('03-wininet'),context));assert.equal(result.result,'stop');assert.equal(result.stage,'layout');assert.equal(opens,0);
});
