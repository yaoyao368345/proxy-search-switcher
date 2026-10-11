const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const files=['src/core/state.cjs','src/core/mihomo.cjs','src/adapters/request.cjs','src/platform/windows/wininet.cjs','src/platform/windows/toolhelp.cjs','src/platform/windows/native.cjs','src/runtime/readonly.cjs'];
const libraries=files.map(file=>fs.readFileSync(path.join(root,file),'utf8').replaceAll('})(globalThis);','})(scope);').replaceAll('typeof module === "object"','false').replaceAll('typeof module==="object"','false'));
const entry=String.raw`
const {classes:Cc,interfaces:Ci,results:Cr}=Components;
const expectedProfile=__PSS_EXPECTED_PROFILE__;
const profile=Services.dirsvc.get("ProfD",Ci.nsIFile);
let report;
if(profile.path!==expectedProfile){report={result:"stop",stage:"profile",reason:"unexpected-profile"};}
else report=await scope.PSSReadonly.runReadonly({
  loadedStatus(){
    const api=ChromeUtils.importESModule("chrome://userchromejs/content/uc_api.sys.mjs");
    const script=api.Scripts.getScriptData("proxy-search-switcher.sys.mjs");
    return script?.isRunning?ChromeUtils.importESModule(script.chromeURI).getStatus():null;
  },
  readConfig(){
    const file=profile.clone();file.append("proxy-search-switcher.local.json");
    if(file.fileSize>65536)throw Error("config-too-large");
    const input=Cc["@mozilla.org/network/file-input-stream;1"].createInstance(Ci.nsIFileInputStream);
    input.init(file,1,0,0);
    const converter=Cc["@mozilla.org/intl/converter-input-stream;1"].createInstance(Ci.nsIConverterInputStream);
    let text="";
    try{converter.init(input,"UTF-8",0,0);const part={};while(converter.readString(4096,part))text+=part.value;}
    finally{converter.close();input.close();}
    return JSON.parse(text.replace(/^\uFEFF/,""));
  },
  requestFactory(){
    const {ServiceRequest}=ChromeUtils.importESModule("resource://gre/modules/ServiceRequest.sys.mjs");
    return scope.PSSRequest.createRequest({ServiceRequest,Ci,Cr,generateQI:ChromeUtils.generateQI});
  },
  nativeFactory(){
    const {ctypes}=ChromeUtils.importESModule("resource://gre/modules/ctypes.sys.mjs");
    const system=Services.dirsvc.get("WinD",Ci.nsIFile);system.append("System32");
    return scope.PSSWindows.createNative(ctypes,system.path);
  }
});
return report;
`;
const profilePath=process.argv[3];
if(!profilePath)throw Error("Pass the expected absolute Zen profile path as the third argument");
const corrected=entry.replace("__PSS_EXPECTED_PROFILE__",JSON.stringify(profilePath));
const source='// One-shot read-only diagnostic. No search mutation, no polling, no secret output.\n(async()=>{\nconst scope={};\n'+libraries.join('\n')+corrected+'\n})().then(report=>console.log("[PSS只读诊断] "+JSON.stringify(report)),()=>console.log("[PSS只读诊断] {\\"result\\":\\"stop\\",\\"reason\\":\\"bootstrap-error\\"}"));\n';
new vm.Script(source);
const output=process.argv[2]||path.join(root,'dist','readonly-diagnostic.js');
fs.mkdirSync(path.dirname(path.resolve(output)),{recursive:true});fs.writeFileSync(output,source,'utf8');
console.log('Built one-shot readonly diagnostic (no local config read during build)');
