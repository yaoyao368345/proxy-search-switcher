const {test}=require('node:test');const assert=require('node:assert/strict');
const {fakeCtypes}=require('./helpers/fake-ctypes.cjs');
const {defineLayout,createWinInet}=require('../src/platform/windows/wininet.cjs');
const {createNative}=require('../src/platform/windows/native.cjs');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const system='C:\\Windows\\System32';
test('Win64 layout has correct offsets even at addresses above Number precision',()=>{
  const f=fakeCtypes(),layout=defineLayout(f.c);assert.equal(layout.info.optionSize,16);assert.equal(layout.info.listSize,32);
  assert.deepEqual(layout.info.optionOffsets,{option:0,value:8});assert.deepEqual(layout.info.listOffsets,{size:0,connection:8,count:16,error:20,options:24});
});
test('wrong pointer width or field size stops before opening libraries',()=>{
  for(const key of ['voidptr_t','uint32_t','char16_t','uint64_t']){const f=fakeCtypes();f.c[key].size=1;assert.throws(()=>createWinInet(f.c,system),e=>e.code==='unsupported-windows-abi');assert.equal(f.opened.length,0);}
});
test('successful single-option calls free returned strings exactly once and skip NULL',()=>{
  const f=fakeCtypes(),reader=createWinInet(f.c,system);assert.deepEqual(reader.readSystem(),{flags:3,server:'127.0.0.1:7897',pac:''});
  assert.deepEqual(f.queries,[10,2,4,10]);assert.equal(f.freed.length,1);assert.equal(f.read.length,1);assert.equal(f.freed[0],f.read[0]);reader.close();reader.close();assert.equal(f.closed.length,2);
});
test('failed query does not dereference or free an unconfirmed nonzero output pointer',()=>{
  const f=fakeCtypes({onQuery:({item,c,setError})=>{item.value=c.char16_t.ptr(0xdead);setError(87);return 0;}}),reader=createWinInet(f.c,system);
  assert.throws(()=>reader.readSystem(),e=>e.code==='wininet-query-failed'&&e.windowsError===87);assert.equal(f.read.length,0);assert.equal(f.freed.length,0);reader.close();assert.equal(f.closed.length,2);
});
test('later query failure leaves earlier confirmed allocation freed, unknown output untouched',()=>{
  const f=fakeCtypes({onQuery:({item,string,c,setError})=>{
    if(item.option===10){item.value=3;return 1;}
    if(item.option===2){item.value=string('secret-native-text');return 1;}
    item.value=c.char16_t.ptr(0xbad);setError(5);return 0;
  }}),reader=createWinInet(f.c,system);
  assert.throws(()=>reader.readSystem(),e=>e.code==='wininet-query-failed'&&e.optionId===4);assert.equal(f.freed.length,1);assert(!f.freed.includes(0xbadn));reader.close();
});
test('string conversion failure still frees caller-owned allocation and redacts exception',()=>{
  const f=fakeCtypes({readStringThrows:true}),reader=createWinInet(f.c,system);
  assert.throws(()=>reader.readSystem(),e=>e.code==='wininet-read-failed'&&!e.message.includes('private'));assert.equal(f.freed.length,1);reader.close();
});
test('malformed successful return releases its transferred allocation before stopping',()=>{
  const f=fakeCtypes({onQuery:({item,list,string})=>{if(item.option===10){item.value=3;return 1;}item.value=string('data');list.count=2;return 1;}}),reader=createWinInet(f.c,system);
  assert.throws(()=>reader.readSystem(),e=>e.code==='wininet-malformed-return');assert.equal(f.freed.length,1);assert.equal(f.read.length,0);reader.close();
});
test('GlobalFree failure stops without retrying or double-freeing',()=>{
  const f=fakeCtypes({freeFailure:true}),reader=createWinInet(f.c,system);assert.throws(()=>reader.readSystem(),e=>e.code==='wininet-free-failed');assert.equal(f.freed.length,1);reader.close();
});
test('mode change during sequential sampling is unknown, all earlier strings released',()=>{
  let count=0;const f=fakeCtypes({onQuery:({item,string})=>{if(item.option===10)item.value=++count===1?3:1;else item.value=string('data');return 1;}}),reader=createWinInet(f.c,system);
  assert.throws(()=>reader.readSystem(),e=>e.code==='wininet-snapshot-changed');assert.equal(f.freed.length,2);reader.close();
});
test('open/declaration errors close already opened DLLs and expose only a safe code',()=>{
  for(const settings of [{openFailure:'kernel32.dll'},{declareFailure:'GlobalFree'}]){const f=fakeCtypes(settings);assert.throws(()=>createWinInet(f.c,system),e=>e.code==='wininet-initialization-failed');assert.equal(f.closed.length,f.opened.length);}
});
test('closing one DLL unsuccessfully still closes the other; future reads are rejected',()=>{
  const f=fakeCtypes({closeFailure:'kernel32.dll'}),reader=createWinInet(f.c,system);assert.throws(()=>reader.close(),e=>e.code==='wininet-library-close-failed');assert.equal(f.closed.length,2);reader.close();assert.throws(()=>reader.readSystem(),e=>e.code==='native-closed');
});
test('all NULL string outputs cause zero dereferences and zero frees',()=>{
  const f=fakeCtypes({onQuery:({item,c})=>{item.value=item.option===10?1:c.char16_t.ptr();return 1;}}),reader=createWinInet(f.c,system);
  assert.deepEqual(reader.readSystem(),{flags:1,server:'',pac:''});assert.equal(f.freed.length,0);assert.equal(f.read.length,0);reader.close();
});
test('production native adapter delegates to the same WinINet reader and closes all DLLs',()=>{
  const f=fakeCtypes(),native=createNative(f.c,system);assert.equal(native.layout.listSize,32);assert.equal(native.readSystem().flags,3);native.close();native.close();assert.equal(f.opened.length,3);assert.equal(f.closed.length,3);
});
test('Toolhelp declaration failure cleans up its kernel and the independent WinINet reader',()=>{
  const f=fakeCtypes({declareFailure:'Process32FirstW'});assert.throws(()=>createNative(f.c,system),e=>e.code==='native-initialization-failed'&&!e.message.includes('private'));assert.equal(f.opened.length,3);assert.equal(f.closed.length,3);
});
test('generated console probe runs the production reader, emits safe flags and closes DLLs',()=>{
  const f=fakeCtypes();const context={ChromeUtils:{importESModule:()=>({ctypes:f.c})},Services:{dirsvc:{get:()=>({path:system,append(){}})}},Components:{interfaces:{}}};
  const source=fs.readFileSync(path.join(__dirname,'../examples/diagnostics/03-wininet.js'),'utf8');
  const result=JSON.parse(vm.runInNewContext(source,context));assert.equal(result.result,'pass');assert.equal(result.listSize,32);assert.equal(result.manualProxy,true);assert.equal(f.freed.length,1);assert.equal(f.closed.length,2);assert(!('server' in result));assert(!('pac' in result));
});
test('generated console probe reports query or cleanup failures without raw native text',()=>{
  for(const settings of [{onQuery:({setError})=>{setError(87);return 0;}},{closeFailure:'kernel32.dll'}]){
    const f=fakeCtypes(settings),context={ChromeUtils:{importESModule:()=>({ctypes:f.c})},Services:{dirsvc:{get:()=>({path:system,append(){}})}},Components:{interfaces:{}}};
    const result=JSON.parse(vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../examples/diagnostics/03-wininet.js'),'utf8'),context));assert.equal(result.result,'stop');assert.equal(f.closed.length,2);assert(!JSON.stringify(result).includes('private'));
  }
});
