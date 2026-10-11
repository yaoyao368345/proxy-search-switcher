const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const files=[
  'src/core/state.cjs','src/core/mihomo.cjs','src/core/switcher.cjs',
  'src/adapters/search.cjs','src/adapters/zen/entry.cjs','src/adapters/firefox/entry.cjs',
  'src/platform/windows/wininet.cjs','src/platform/windows/toolhelp.cjs','src/platform/windows/native.cjs','src/adapters/request.cjs','src/runtime/start.cjs',
];
const source='// ==UserScript==\n// @name Proxy Search Switcher\n// @version 0.1.0-beta.1\n// @description Switch the real default search engine from explicit proxy state\n// ==/UserScript==\nconst scope = {};\n'+files.map(file=>`\n// ${file}\n${fs.readFileSync(path.join(root,file),'utf8').replaceAll('})(globalThis);','})(scope);')}`).join('\n');
new vm.Script(source,{filename:'proxy-search-switcher.sys.mjs'});
const moduleSource=source+'\nexport function getStatus() { return scope.PSSInstance?.status; }\nexport function stop() { scope.PSSInstance?.stop?.(); }\n';
fs.mkdirSync(path.join(root,'dist'),{recursive:true});
fs.writeFileSync(path.join(root,'dist','proxy-search-switcher.sys.mjs'),moduleSource,'utf8');
console.log('Built dist/proxy-search-switcher.sys.mjs for existing fx-autoconfig');
