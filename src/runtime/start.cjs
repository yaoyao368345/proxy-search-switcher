(function(root) {
  "use strict";
  // The build replaces only this marker with a non-secret, absolute config path.
  const INSTALL={browser:"zen",configPath:"__PSS_CONFIG_PATH__"};
  if(root.PSSInstance)return;
  root.PSSInstance={status:"waiting"};
  if(typeof ChromeUtils === "undefined" || typeof Components === "undefined") {
    root.PSSInstance.status="blocked:sandbox";
    // Never change sandbox policy or attempt to escape a privilege boundary.
    return;
  }
  const {classes:Cc,interfaces:Ci,results:Cr}=Components;
  const services=Services; // Modern Gecko exposes Services as a chrome global.
  if(services.appinfo.processType!==services.appinfo.PROCESS_TYPE_DEFAULT)return;
  let switcher,native,transport,readyObserver,shutdownObserver,quitting=false;
  const status=code=>{root.PSSInstance.status=code;};
  function stop(){switcher?.stop();transport?.close();native?.close();status("stopped");}
  async function initialize() {
    try {
      if(quitting)return;
      const configFile=Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
      if(INSTALL.configPath==="__PSS_CONFIG_PATH__") {
        configFile.initWithFile(services.dirsvc.get("ProfD",Ci.nsIFile));
        configFile.append("proxy-search-switcher.local.json");
      } else configFile.initWithPath(INSTALL.configPath);
      if(configFile.fileSize>65536)throw Error("config-too-large");
      const input=Cc["@mozilla.org/network/file-input-stream;1"].createInstance(Ci.nsIFileInputStream);
      input.init(configFile,1,0,0);
      const converter=Cc["@mozilla.org/intl/converter-input-stream;1"].createInstance(Ci.nsIConverterInputStream);
      let text="";
      try {
        converter.init(input,"UTF-8",0,0);
        const part={};while(converter.readString(4096,part))text+=part.value;
      } finally {converter.close();input.close();}
      const config=root.PSSState.validateConfig(JSON.parse(text.replace(/^\uFEFF/,"")));
      if(!config.enabled){status("disabled");return;}
      const search=(INSTALL.browser==="zen"?root.PSSZen:root.PSSFirefox).load(
        uri=>ChromeUtils.importESModule(uri),services.appinfo.name,
      );
      const {ctypes}=ChromeUtils.importESModule("resource://gre/modules/ctypes.sys.mjs");
      const system=services.dirsvc.get("WinD",Ci.nsIFile);system.append("System32");
      native=root.PSSWindows.createNative(ctypes,system.path);
      const {ServiceRequest}=ChromeUtils.importESModule("resource://gre/modules/ServiceRequest.sys.mjs");
      transport=root.PSSRequest.createRequest({ServiceRequest,Ci,Cr,generateQI:ChromeUtils.generateQI});
      const timers=ChromeUtils.importESModule("resource://gre/modules/Timer.sys.mjs");
      const log=code=>{
        status(code);
        if(config.debug)services.console.logStringMessage("[Proxy Search Switcher] "+code);
      };
      switcher=root.PSSSwitcher.createSwitcher({config,search,timers,log,
        detectSystem:()=>root.PSSState.classifySystem(native.readSystem(),config),
        detectTun:()=>root.PSSMihomo.detectTun(config,transport.request,native.readProcesses),
      });
      await switcher.start();
    } catch {stop();status("blocked:capability-or-config");services.console.logStringMessage("[Proxy Search Switcher] Stopped: incompatible capability or local config. No settings changed.");}
  }
  // Delay until the profile and first browser window are ready. Remove the
  // observer before initialization, so multiple windows cannot spawn pollers.
  readyObserver={observe(){services.obs.removeObserver(readyObserver,"browser-delayed-startup-finished");readyObserver=null;void initialize();}};
  shutdownObserver={observe(){
    quitting=true;
    if(readyObserver)services.obs.removeObserver(readyObserver,"browser-delayed-startup-finished");
    services.obs.removeObserver(shutdownObserver,"quit-application-granted");stop();
  }};
  services.obs.addObserver(readyObserver,"browser-delayed-startup-finished");
  services.obs.addObserver(shutdownObserver,"quit-application-granted");
  root.PSSInstance.stop=stop;
})(globalThis);
