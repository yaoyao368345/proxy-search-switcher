(function(root) {
  "use strict";
  const common = typeof module === "object" ? require("../search.cjs") : root.PSSSearch;
  function load(importModule, appName) {
    if (appName !== "Zen") throw Error("wrong-browser");
    return common.loadSearch(importModule);
  }
  const api = { load };
  if (typeof module === "object") module.exports = api;
  else root.PSSZen = api;
})(globalThis);
