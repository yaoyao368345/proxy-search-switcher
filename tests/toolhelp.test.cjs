const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const {fakeCtypes}=require('./helpers/fake-ctypes.cjs');
const {defineLayout,createToolhelp}=require('../src/platform/windows/toolhelp.cjs');
const system='C:\\Windows\\System32';
function fixture(options={}){
  const f=fakeCtypes(options),open=f.c.open;let error=0,index=-1;const handles=[];
  Object.defineProperty(f.c,"winLastError",{get:()=>error,configurable:true});
  f.c.open=path=>{const lib=open(path),declare=lib.declare;
    lib.declare=name=>{
      if(options.declareFailure===name)return declare(name);
      if(name==='GetLastError')throw Error('must-use-saved-error');
      if(name==='CreateToolhelp32Snapshot')return (flags,pid)=>{assert.equal(flags,2);assert.equal(pid,0);error=5;return f.c.voidptr_t(options.nullHandle?0:options.invalidHandle?0xffffffffffffffffn:123);};
      if(name==='CloseHandle')return h=>{handles.push(h.addressValue);error=6;if(options.closeThrows)throw Error('sensitive-path');return options.closeHandleFailure?0:1;};
      if(name==='Process32FirstW'||name==='Process32NextW')return (_h,p)=>{
        if(name==='Process32FirstW'){index=0;assert.equal(p.contents.size,568);}else index++;
        if(options.readThrows)throw Error('sensitive-path');
        const names=options.names||['private-process.exe','MIHOMO.EXE'];
        if(index>=names.length || options.firstFailure || (options.partialFailure&&index===1)){error=options.firstFailure||options.partialFailure?5:(options.terminatorError??18);return 0;}
        p.contents.exe={readString(){if(options.stringThrows)throw Error('sensitive-path');return names[index];}};return 1;
      };
      return declare(name);
    };return lib;};return {...f,handles};
}
test('Toolhelp x64 layout checks every field above Number precision',()=>{
 const f=fixture(),l=defineLayout(f.c);assert.equal(l.info.processSize,568);assert.deepEqual(l.info.offsets,{size:0,usage:4,pid:8,heap:16,module:24,threads:28,parent:32,priority:36,flags:40,exe:44});
 f.c.uintptr_t.size=4;assert.throws(()=>createToolhelp(f.c,system),e=>e.code==='unsupported-windows-abi');assert.equal(f.opened.length,0);
});
test('same size but incorrect offset is rejected before opening DLL',()=>{
 const f=fixture(),original=f.c.StructType;f.c.StructType=(...args)=>{const T=original(...args);return Object.assign(function(){const p=T(),field=p.addressOfField;p.addressOfField=n=>field(n==='heap'?'pid':n);return p;},T);};
 assert.throws(()=>createToolhelp(f.c,system),e=>e.code==='unsupported-toolhelp-layout');assert.equal(f.opened.length,0);
});
test('complete snapshot returns lowercase names and closes handle and DLL once',()=>{
 const f=fixture(),r=createToolhelp(f.c,system);assert.deepEqual(r.readProcesses(),['private-process.exe','mihomo.exe']);assert.deepEqual(f.handles,[123n]);r.close();r.close();assert.equal(f.closed.length,1);assert.throws(()=>r.readProcesses(),e=>e.code==='native-closed');
});
test('empty complete snapshot is distinct from failure',()=>{const f=fixture({names:[]}),r=createToolhelp(f.c,system);assert.deepEqual(r.readProcesses(),[]);assert.equal(f.handles.length,1);r.close();});
for(const key of ['nullHandle','invalidHandle'])test(key+' never closes an unowned handle',()=>{const f=fixture({[key]:true}),r=createToolhelp(f.c,system);assert.throws(()=>r.readProcesses(),e=>e.code==='process-snapshot-failed'&&e.windowsError===5);assert.equal(f.handles.length,0);r.close();});
for(const key of ['firstFailure','partialFailure','readThrows','stringThrows','closeHandleFailure','closeThrows'])test(key+' stops safely and attempts owned handle close exactly once',()=>{
 const f=fixture({[key]:true}),r=createToolhelp(f.c,system);assert.throws(()=>r.readProcesses(),e=>!!e.code&&!e.message.includes('sensitive'));assert.equal(f.handles.length,1);r.close();assert.equal(f.closed.length,1);
});
test('declaration and DLL close failures are sanitized',()=>{
 const f=fixture({declareFailure:'Process32FirstW'});assert.throws(()=>createToolhelp(f.c,system),e=>e.code==='native-initialization-failed');assert.equal(f.closed.length,1);
 const g=fixture({closeFailure:'kernel32.dll'}),r=createToolhelp(g.c,system);assert.throws(()=>r.close(),e=>e.code==='toolhelp-library-close-failed');r.close();assert.equal(g.closed.length,1);
});
test('generated diagnostic shares production core and never exposes process names',()=>{
 const source=fs.readFileSync(require.resolve('../examples/diagnostics/04-toolhelp.js'),'utf8');
 assert(source.includes(fs.readFileSync(require.resolve('../src/platform/windows/toolhelp.cjs'),'utf8').replaceAll('})(globalThis);','})(scope);')));
 for(const options of [{},{names:['private-process.exe']},{partialFailure:true},{closeHandleFailure:true},{closeFailure:'kernel32.dll'}]){
 const f=fixture(options),context={ChromeUtils:{importESModule:()=>({ctypes:f.c})},Services:{dirsvc:{get:()=>({path:system,append(){}})}},Components:{interfaces:{}}};
 const text=vm.runInNewContext(source,context),out=JSON.parse(text);assert(!text.includes('private-process'));assert(!text.includes(system));assert.equal(f.closed.length,1);assert.equal(out.result,(options.partialFailure||options.closeHandleFailure||options.closeFailure)?'stop':'pass');if(out.result==='pass')assert.equal(out.corePresent,!options.names);
 }
});

test('saved FFI error is read before CloseHandle overwrites it',()=>{
 const f=fixture({partialFailure:true}),r=createToolhelp(f.c,system);
 assert.throws(()=>r.readProcesses(),e=>e.code==='process-enumeration-incomplete'&&e.windowsError===5);
 assert.equal(f.c.winLastError,6);assert.equal(f.handles.length,1);r.close();
});

test('zero saved error never proves complete enumeration',()=>{
 const f=fixture({terminatorError:0}),r=createToolhelp(f.c,system);
 assert.throws(()=>r.readProcesses(),e=>e.code==='process-enumeration-incomplete'&&e.windowsError===0);r.close();
});
test('production bundle embeds the exact validated Toolhelp and WinINet cores',()=>{
 const path=require('node:path'),root=path.resolve(__dirname,'..');
 const bundle=fs.readFileSync(path.join(root,'dist/proxy-search-switcher.sys.mjs'),'utf8');
 for(const name of ['toolhelp','wininet']){
  const core=fs.readFileSync(path.join(root,'src/platform/windows/'+name+'.cjs'),'utf8').replaceAll('})(globalThis);','})(scope);');
  assert(bundle.includes(core));
 }
 assert(bundle.includes('processReader=toolhelp.createToolhelp'));
 assert(!bundle.includes('declare("GetLastError"'));
});
