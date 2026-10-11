(function(root) {
  "use strict";
  const MODULE = "moz-src:///toolkit/components/search/SearchService.sys.mjs";
  function loadSearch(importModule) {
    const search = importModule(MODULE)?.SearchService;
    if (!search || ["init", "getDefault", "setDefault", "getEngineByName"].some(key => typeof search[key] !== "function") ||
        search.CHANGE_REASON?.USER === undefined) throw Error("search-service-incompatible");
    return search;
  }
  const api = { loadSearch, MODULE };
  if (typeof module === "object") module.exports = api;
  else root.PSSSearch = api;
})(globalThis);
