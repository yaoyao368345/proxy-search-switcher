(function(root) {
  "use strict";
  const wininet=typeof module === "object"?require("./wininet.cjs"):root.PSSWinInet;
  const toolhelp=typeof module === "object"?require("./toolhelp.cjs"):root.PSSToolhelp;
  function createNative(ctypes,systemDirectory){
    wininet.defineLayout(ctypes);toolhelp.defineLayout(ctypes);
    let reader,processReader,closed=false;
    function close(){
      if(closed)return;closed=true;let failed=false;
      try{processReader?.close();}catch{failed=true;}
      try{reader?.close();}catch{failed=true;}
      if(failed)throw Object.assign(Error("native-library-close-failed"),{code:"native-library-close-failed"});
    }
    try{
      reader=wininet.createWinInet(ctypes,systemDirectory);
      processReader=toolhelp.createToolhelp(ctypes,systemDirectory);
      return {readSystem:reader.readSystem,readProcesses:processReader.readProcesses,close,layout:reader.layout};
    }catch(error){try{close();}catch{}if(error?.code)throw error;throw Object.assign(Error("native-initialization-failed"),{code:"native-initialization-failed"});}
  }
  const api={createNative};
  if(typeof module === "object")module.exports=api;else root.PSSWindows=api;
})(globalThis);
