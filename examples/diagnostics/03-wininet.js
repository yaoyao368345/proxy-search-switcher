// Generated from src/platform/windows/wininet.cjs. Paste code directly into the parent-process console.
(()=>{
const scope={};
(function(root){
  "use strict";
  function failure(code,details={}){return Object.assign(Error(code),{code,...details});}
  function defineLayout(c){
    if(c.voidptr_t.size!==8 || c.uint32_t.size!==4 || c.char16_t.size!==2 || c.uint64_t.size!==8)throw failure("unsupported-windows-abi");
    const D=c.uint32_t,W=c.char16_t.ptr;
    // js-ctypes has no UnionType. uint64_t is raw 8-byte/alignment-8 storage
    // for the Win64 union {DWORD, LPWSTR, FILETIME}; never convert pointers to Number.
    const Option=c.StructType("PSSOption",[{option:D},{value:c.uint64_t}]);
    const List=c.StructType("PSSOptionList",[{size:D},{connection:W},{count:D},{error:D},{options:Option.ptr}]);
    const address=p=>BigInt(c.cast(p,c.uintptr_t).value.toString());
    function offsets(Type,names){const instance=Type(),base=address(instance.address());return Object.fromEntries(names.map(name=>[name,Number(address(instance.addressOfField(name))-base)]));}
    const optionOffsets=offsets(Option,["option","value"]),listOffsets=offsets(List,["size","connection","count","error","options"]);
    if(Option.size!==16 || List.size!==32 || optionOffsets.option!==0 || optionOffsets.value!==8 ||
       ["size","connection","count","error","options"].some((name,i)=>listOffsets[name]!==[0,8,16,20,24][i]))throw failure("unsupported-native-layout");
    return {Option,List,info:{pointerSize:8,optionSize:Option.size,listSize:List.size,optionOffsets,listOffsets}};
  }
  function createWinInet(c,systemDirectory){
    const layout=defineLayout(c),{Option,List}=layout;
    const D=c.uint32_t,P=c.voidptr_t,W=c.char16_t.ptr,libraries=[];
    let closed=false;
    function close(){
      if(closed)return;closed=true;
      let failed=false;for(const lib of libraries.slice().reverse()){try{lib.close();}catch{failed=true;}}
      if(failed)throw failure("wininet-library-close-failed");
    }
    try{
      const wininet=c.open(systemDirectory+"\\wininet.dll");libraries.push(wininet);
      const kernel=c.open(systemDirectory+"\\kernel32.dll");libraries.push(kernel);
      const query=wininet.declare("InternetQueryOptionW",c.winapi_abi,c.int32_t,P,D,P,D.ptr);
      const free=kernel.declare("GlobalFree",c.winapi_abi,P,P);
      // Consult Gecko's saved LastError; another FFI call resets thread state.
      function queryOne(id,stringResult){
        if(closed)throw failure("native-closed");
        const options=Option.array(1)();options[0].option=id;options[0].value=0;
        const list=List();list.size=List.size;list.connection=W();list.count=1;list.error=0;list.options=options.addressOfElement(0);
        const size=D(List.size);
        const ok=query(P(),75,c.cast(list.address(),P),size.address());
        // FALSE does not establish ownership of any output bytes. In particular
        // never dereference or GlobalFree an unconfirmed/partially written union.
        if(!ok)throw failure("wininet-query-failed",{optionId:id,windowsError:Number(c.winLastError)});
        // Only a successful one-option query transfers its string allocation.
        const pointer=stringResult?c.cast(options[0].addressOfField("value"),W.ptr).contents:null;
        try{
          if(size.value!==List.size || list.count!==1 || options[0].option!==id)throw failure("wininet-malformed-return");
          return stringResult?(pointer.isNull()?"":pointer.readString()):c.cast(options[0].addressOfField("value"),D.ptr).contents;
        }finally{
          if(pointer && !pointer.isNull()){
            const remaining=free(c.cast(pointer,P));
            if(!remaining.isNull())throw failure("wininet-free-failed",{optionId:id});
          }
        }
      }
      function readSystem(){
        try{
          const flags=queryOne(10,false),server=queryOne(2,true),pac=queryOne(4,true);
          // Sequential calls avoid ambiguous per-option ownership on failure.
          // Guard a mode change during the small sampling window.
          if(queryOne(10,false)!==flags)throw failure("wininet-snapshot-changed");
          return {flags,server,pac};
        }catch(error){if(error?.code)throw error;throw failure("wininet-read-failed");}
      }
      return {readSystem,close,layout:layout.info};
    }catch(error){try{close();}catch{}if(error?.code)throw error;throw failure("wininet-initialization-failed");}
  }
  const api={defineLayout,createWinInet};
  if(false)module.exports=api;else root.PSSWinInet=api;
})(scope);

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

})()
