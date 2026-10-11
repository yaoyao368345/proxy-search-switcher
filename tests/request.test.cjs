const {test}=require('node:test');const assert=require('node:assert/strict');
const {createRequest}=require('../src/adapters/request.cjs');const {validateConfig}=require('../src/core/state.cjs');
function fixture(send) {
  let xhr;class FakeXHR {
    constructor(options){assert.equal(options.mozAnon,true);xhr=this;this.channel={status:0};this.bypassProxy=true;this.headers={};}
    open(method,url,options){this.url=url;assert.equal(method,'GET');assert.equal(options.bypassProxy,true);}
    setRequestHeader(k,v){this.headers[k]=v;}
    send(){send(this);}
    abort(){this.onabort?.();}
  }
  return {api:createRequest({ServiceRequest:FakeXHR,Ci:{},Cr:{NS_ERROR_ABORT:1,NS_ERROR_CONNECTION_REFUSED:2},generateQI:()=>function(){return this;}}),get xhr(){return xhr;}};
}
test('request includes bearer only for exact loopback configs URL',async()=>{
  const f=fixture(x=>{x.status=200;x.responseText='{}';x.onload();});await f.api.request(validateConfig({token:'test-token'}));assert.equal(f.xhr.url,'http://127.0.0.1:9097/configs');assert.equal(f.xhr.headers.Authorization,'Bearer test-token');
});
test('redirect is rejected before secret can leave local origin',async()=>{
  let redirectCode;const f=fixture(x=>x.channel.notificationCallbacks.asyncOnChannelRedirect(null,null,0,{onRedirectVerifyCallback:v=>redirectCode=v}));
  await assert.rejects(f.api.request(validateConfig({token:'test-token'})),e=>e.code==='redirect-rejected');assert.equal(redirectCode,1);
});
test('timeout, refused connection and response limit have distinct codes',async()=>{
  for(const [action,code]of [[x=>x.ontimeout(),'timeout'],[x=>{x.channel.status=2;x.onerror();},'connection-refused'],[x=>x.onprogress({loaded:1048577}),'response-too-large']]){
    const f=fixture(action);await assert.rejects(f.api.request(validateConfig({})),e=>e.code===code);
  }
});
test('shutdown aborts outstanding requests',async()=>{
  const f=fixture(()=>{});const p=f.api.request(validateConfig({}));f.api.close();await assert.rejects(p,e=>e.code==='aborted');
});
