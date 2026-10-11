(function(root) {
  "use strict";
  const common = typeof module === "object" ? require("../search.cjs") : root.PSSSearch;
  function load(importModule, appName) {
    if (appName !== "Firefox") throw Error("wrong-browser");
    // Old Services.search and legacy XPCOM contracts are deliberately not used.
    // Older versions without this module must stop rather than guess a fallback.
    return common.loadSearch(importModule);
  }
  const api = { load };
  if (typeof module === "object") module.exports = api;
  else root.PSSFirefox = api;
})(globalThis);
