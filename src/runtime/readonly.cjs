(function(root){
  "use strict";
  const state=typeof module === "object"?require("../core/state.cjs"):root.PSSState;
  const mihomo=typeof module === "object"?require("../core/mihomo.cjs"):root.PSSMihomo;
  async function runReadonly({readConfig,requestFactory,nativeFactory,loadedStatus}){
    const report={mode:"read-only",controller:"http://127.0.0.1:9097",automaticSwitching:false,stage:"loader"};
    let transport,native;
    try{
      if(loadedStatus()!=="disabled")return {...report,result:"stop",reason:"module-not-disabled"};
      report.stage="config";
      const config=state.validateConfig(await readConfig());
      if(config.enabled)return {...report,result:"stop",reason:"config-not-disabled"};
      if(config.controllerUrl!==report.controller)return {...report,result:"stop",reason:"unexpected-controller"};
      if(!config.token)return {...report,result:"stop",reason:"token-empty"};
      report.stage="api";
      transport=requestFactory();
      // Native shutdown inference is intentionally excluded from this API check.
      report.tun=await mihomo.detectTun(config,transport.request,()=>null);
      if(report.tun.reason!=="api-confirmed")return {...report,result:"stop",reason:report.tun.reason};
      report.stage="windows";
      native=nativeFactory();
      const snapshot=native.readSystem();
      report.system=state.classifySystem(snapshot,config);
      report.manualProxyFlag=!!(snapshot.flags&2);
      report.pacFlag=!!(snapshot.flags&4);
      report.autoDetectFlag=!!(snapshot.flags&8);
      if(report.system.state==="unknown")return {...report,result:"stop",reason:report.system.reason};
      report.stage="process-snapshot";
      const processes=native.readProcesses();
      report.corePresent=processes.some(name=>config.coreProcessNames.includes(name.toLowerCase()));
      report.wouldUse=state.decide(report.system,report.tun);
      return {...report,stage:"complete",result:"pass"};
    }catch(error){return {...report,result:"stop",reason:"diagnostic-exception",errorType:error instanceof TypeError?"TypeError":"Error"};}
    finally{try{transport?.close();}catch{}try{native?.close();}catch{}}
  }
  if(typeof module==="object")module.exports={runReadonly};else root.PSSReadonly={runReadonly};
})(globalThis);
