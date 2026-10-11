(function(root) {
  "use strict";
  function createRequest({ ServiceRequest, Ci, Cr, generateQI }) {
    const pending=new Set();
    function request(config) {
      return new Promise((resolve,reject)=>{
        const xhr=new ServiceRequest({mozAnon:true});
        pending.add(xhr);
        let settled=false;
        const done=(error,response)=>{
          if(settled)return;settled=true;pending.delete(xhr);
          xhr.onload=xhr.onerror=xhr.ontimeout=xhr.onabort=xhr.onprogress=null;
          if(error)reject(error);else resolve(response);
        };
        const fail=code=>done({code});
        try {
          xhr.open("GET",config.controllerUrl+"/configs",{bypassProxy:true});
          if(!xhr.bypassProxy) { fail("direct-request-unavailable");xhr.abort();return; }
          xhr.timeout=config.timeoutMs;
          // Never follow a redirect carrying a local API secret to another origin.
          xhr.channel.notificationCallbacks={
            QueryInterface:generateQI(["nsIInterfaceRequestor","nsIChannelEventSink"]),
            getInterface(iid) { return this.QueryInterface(iid); },
            asyncOnChannelRedirect(_old,_new,_flags,callback) {
              fail("redirect-rejected");callback.onRedirectVerifyCallback(Cr.NS_ERROR_ABORT);
            },
          };
          if(config.token) xhr.setRequestHeader("Authorization","Bearer "+config.token);
          xhr.onload=()=>{
            if(xhr.responseText.length>1024*1024){fail("response-too-large");return;}
            done(null,{status:xhr.status,text:xhr.responseText});
          };
          xhr.ontimeout=()=>fail("timeout");xhr.onabort=()=>fail("aborted");
          xhr.onerror=()=>{
            let refused=false;
            try { refused=xhr.channel.status===Cr.NS_ERROR_CONNECTION_REFUSED; } catch {}
            fail(refused?"connection-refused":"network");
          };
          xhr.onprogress=event=>{if(event.loaded>1024*1024){fail("response-too-large");xhr.abort();}};
          xhr.send();
        } catch { fail("request-incompatible");try{xhr.abort();}catch{} }
      });
    }
    function close(){for(const xhr of [...pending])xhr.abort();pending.clear();}
    return {request,close};
  }
  const api={createRequest};
  if(typeof module === "object")module.exports=api;
  else root.PSSRequest=api;
})(globalThis);
