const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const native=fs.readFileSync(path.join(root,'src/platform/windows/wininet.cjs'),'utf8').replaceAll('})(globalThis);','})(scope);').replaceAll('typeof module==="object"','false');
const wrapper=String.raw`
let reader,stage="layout",report;
try{
  const {ctypes:c}=ChromeUtils.importESModule("resource://gre/modules/ctypes.sys.mjs");
  const system=Services.dirsvc.get("WinD",Components.interfaces.nsIFile);system.append("System32");
  reader=scope.PSSWinInet.createWinInet(c,system.path);
  stage="query";
  const snapshot=reader.readSystem();
  report={result:"pass",...reader.layout,flags:snapshot.flags,
    manualProxy:!!(snapshot.flags&2),pacEnabled:!!(snapshot.flags&4),autoDetect:!!(snapshot.flags&8),
    matchesExpectedClashEndpoint:snapshot.server==="127.0.0.1:7897",pacUrlPresent:!!snapshot.pac,automaticSwitching:false};
}catch(error){
  report={result:"stop",stage,reason:error?.code||"native-diagnostic-failed",
    ...(Number.isInteger(error?.optionId)?{optionId:error.optionId}:{}),
    ...(Number.isInteger(error?.windowsError)?{windowsError:error.windowsError}:{})};
}finally{try{reader?.close();}catch{report={result:"stop",stage:"cleanup",reason:"wininet-library-close-failed"};}}
return JSON.stringify(report);
`;
const source='// Generated from src/platform/windows/wininet.cjs. Paste code directly into the parent-process console.\n(()=>{\nconst scope={};\n'+native+wrapper+'\n})()\n';
new vm.Script(source);
const output=process.argv[2]||path.join(root,'examples/diagnostics/03-wininet.js');
fs.mkdirSync(path.dirname(path.resolve(output)),{recursive:true});fs.writeFileSync(output,source,'utf8');
console.log('Built one-shot WinINet diagnostic from production module (no config or API access)');
