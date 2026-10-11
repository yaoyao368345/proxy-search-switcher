(() => {
  const api = ChromeUtils.importESModule("chrome://userchromejs/content/uc_api.sys.mjs");
  const script = api.Scripts.getScriptData("proxy-search-switcher.sys.mjs");
  const status = script?.isRunning
    ? ChromeUtils.importESModule(script.chromeURI).getStatus() : null;
  return JSON.stringify({
    loaderVersion: api.Runtime.loaderVersion,
    loadedByLoader: script?.isRunning === true,
    status,
    configValidatedAtStartup: status === "disabled",
    startupOutcome: status === "disabled" ? "configuration-disabled-before-detectors" : "requires-analysis"
  });
})()
