// Generated from production Toolhelp core. Paste directly; do not load via file URI.
(()=>{
const scope={};
(function(root){
  "use strict";
  const failure=(code,details={})=>Object.assign(Error(code),{code,...details});
  function defineLayout(c){
    if(c.voidptr_t.size!==8 || c.uintptr_t.size!==8 || c.uint32_t.size!==4 || c.int32_t.size!==4 || c.char16_t.size!==2)throw failure("unsupported-windows-abi");
    const D=c.uint32_t;
    const Process=c.StructType("PSSProcess",[{size:D},{usage:D},{pid:D},{heap:c.uintptr_t},{module:D},{threads:D},{parent:D},{priority:c.int32_t},{flags:D},{exe:c.char16_t.array(260)}]);
    const names=["size","usage","pid","heap","module","threads","parent","priority","flags","exe"];
    const p=Process(),address=v=>BigInt(c.cast(v,c.uintptr_t).value.toString()),base=address(p.address());
    const offsets=Object.fromEntries(names.map(n=>[n,Number(address(p.addressOfField(n))-base)]));
    if(Process.size!==568 || names.some((n,i)=>offsets[n]!==[0,4,8,16,24,28,32,36,40,44][i]))throw failure("unsupported-toolhelp-layout");
    return {Process,info:{pointerSize:8,processSize:Process.size,offsets}};
  }
  function createToolhelp(c,systemDirectory){
    const {Process,info}=defineLayout(c);let kernel,closed=false;
    function close(){if(closed)return;closed=true;try{kernel?.close();}catch{throw failure("toolhelp-library-close-failed");}}
    try{
      kernel=c.open(systemDirectory+"\\kernel32.dll");
      const D=c.uint32_t,P=c.voidptr_t,B=c.int32_t,a=c.winapi_abi;
      const snapshot=kernel.declare("CreateToolhelp32Snapshot",a,P,D,D);
      const first=kernel.declare("Process32FirstW",a,B,P,Process.ptr);
      const next=kernel.declare("Process32NextW",a,B,P,Process.ptr);
      const release=kernel.declare("CloseHandle",a,B,P);
      // Gecko clears thread LastError before FFI calls; use its saved result.
      function readProcesses(){
        if(closed)throw failure("native-closed");
        try{
          const handle=snapshot(2,0);const snapshotError=Number(c.winLastError);
          // INVALID_HANDLE_VALUE is all bits set; unsigned comparison avoids signed cast ambiguity.
          if(handle.isNull() || BigInt(c.cast(handle,c.uintptr_t).value.toString())===0xffffffffffffffffn)throw failure("process-snapshot-failed",{windowsError:snapshotError});
          let result,error;
          try{
            const process=Process();process.size=Process.size;const names=[];
            let ok=first(handle,process.address());
            while(ok){names.push(process.exe.readString().toLowerCase());ok=next(handle,process.address());}
            const code=Number(c.winLastError);
            if(code!==18)throw failure("process-enumeration-incomplete",{windowsError:code});
            result=names;
          }catch(e){error=e?.code?e:failure("process-read-failed");}
          finally{
            // Exactly one close attempt per valid owned snapshot, including read failure.
            if(!release(handle))error=failure("process-handle-close-failed",{windowsError:Number(c.winLastError)});
          }
          if(error)throw error;return result;
        }catch(e){throw e?.code?e:failure("process-native-call-failed");}
      }
      return {readProcesses,close,layout:info};
    }catch(e){try{close();}catch{}throw e?.code?e:failure("native-initialization-failed");}
  }
  const api={defineLayout,createToolhelp};
  if(typeof module === "object")module.exports=api;else root.PSSToolhelp=api;
})(scope);

let reader,stage="layout",report;
try{
  const {ctypes:c}=ChromeUtils.importESModule("resource://gre/modules/ctypes.sys.mjs");
  const system=Services.dirsvc.get("WinD",Components.interfaces.nsIFile);system.append("System32");
  reader=scope.PSSToolhelp.createToolhelp(c,system.path);stage="snapshot";
  const names=reader.readProcesses();
  report={result:"pass",status:"snapshot-complete-handle-closed",corePresent:names.some(n=>["verge-mihomo.exe","mihomo.exe","clash-meta.exe"].includes(n)),...reader.layout,automaticSwitching:false};
}catch(e){report={result:"stop",stage,reason:e?.code||"toolhelp-diagnostic-failed",...(Number.isInteger(e?.windowsError)?{windowsError:e.windowsError}:{})};}
finally{try{reader?.close();}catch{report={result:"stop",stage:"cleanup",reason:"toolhelp-library-close-failed"};}}
return JSON.stringify(report);

})()
