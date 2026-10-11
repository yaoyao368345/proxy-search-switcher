const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const native=fs.readFileSync(path.join(root,'src/platform/windows/toolhelp.cjs'),'utf8').replaceAll('})(globalThis);','})(scope);');
const {validateConfig}=require('../src/core/state.cjs');
const trusted=validateConfig({}).coreProcessNames;
const wrapper=`
let reader,stage="layout",report;
try{
  const {ctypes:c}=ChromeUtils.importESModule("resource://gre/modules/ctypes.sys.mjs");
  const system=Services.dirsvc.get("WinD",Components.interfaces.nsIFile);system.append("System32");
  reader=scope.PSSToolhelp.createToolhelp(c,system.path);stage="snapshot";
  const names=reader.readProcesses();
  report={result:"pass",status:"snapshot-complete-handle-closed",corePresent:names.some(n=>${JSON.stringify(trusted)}.includes(n)),...reader.layout,automaticSwitching:false};
}catch(e){report={result:"stop",stage,reason:e?.code||"toolhelp-diagnostic-failed",...(Number.isInteger(e?.windowsError)?{windowsError:e.windowsError}:{})};}
finally{try{reader?.close();}catch{report={result:"stop",stage:"cleanup",reason:"toolhelp-library-close-failed"};}}
return JSON.stringify(report);
`;
const source='// Generated from production Toolhelp core. Paste directly; do not load via file URI.\n(()=>{\nconst scope={};\n'+native+wrapper+'\n})()\n';
new vm.Script(source);
const output=process.argv[2]||path.join(root,'examples/diagnostics/04-toolhelp.js');
fs.mkdirSync(path.dirname(path.resolve(output)),{recursive:true});fs.writeFileSync(output,source,'utf8');
console.log('Built one-shot Toolhelp diagnostic (no config, API or timers)');
