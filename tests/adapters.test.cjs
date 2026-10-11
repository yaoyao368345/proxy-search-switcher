const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const zen=require('../src/adapters/zen/entry.cjs'),firefox=require('../src/adapters/firefox/entry.cjs');
const {MODULE}=require('../src/adapters/search.cjs');
for(const [adapter,name]of [[zen,'Zen'],[firefox,'Firefox']]) {
  test(name+' probes modern module and required methods',()=>{
    const search={init(){},getDefault(){},setDefault(){},getEngineByName(){},CHANGE_REASON:{USER:0}};
    assert.equal(adapter.load(uri=>{assert.equal(uri,MODULE);return {SearchService:search};},name),search);
    assert.throws(()=>adapter.load(()=>({SearchService:{}}),name));
    assert.throws(()=>adapter.load(()=>{throw Error('missing module');},name));
    assert.throws(()=>adapter.load(()=>({SearchService:search}),'Other'));
  });
}
test('build evaluates safely inside a default sandbox without changing prefs',()=>{
  const context={};vm.createContext(context);
  const source=fs.readFileSync(path.join(__dirname,'../dist/proxy-search-switcher.sys.mjs'),'utf8').replace(/^export /gm,'');
  vm.runInContext(source,context);
  assert.equal(context.getStatus(),'blocked:sandbox');
});
test('native adapter rejects unverified pointer ABI before DLL loading',()=>{
  const {createNative}=require('../src/platform/windows/native.cjs');
  assert.throws(()=>createNative({voidptr_t:{size:4}},'C:\\Windows\\System32'),/unsupported-windows-abi/);
});

test('distribution version metadata matches package version without changing core source',()=>{
 const pkg=JSON.parse(fs.readFileSync(require.resolve('../package.json'),'utf8'));
 const built=fs.readFileSync(require.resolve('../dist/proxy-search-switcher.sys.mjs'),'utf8');
 assert(built.includes('// @version '+pkg.version+'\n'));
 const installer=fs.readFileSync(require.resolve('../installer/Common.ps1'),'utf8');
 assert(installer.includes('@version '+pkg.version+'`n'));
});
