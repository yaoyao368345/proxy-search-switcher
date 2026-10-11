(async () => {
  const { classes: Cc, interfaces: Ci, results: Cr } = Components;
  const file = Services.dirsvc.get("ProfD", Ci.nsIFile).clone();
  file.append("proxy-search-switcher.local.json");
  let xhr, stage = "config";
  try {
    if (file.fileSize > 65536) throw Error();
    const input = Cc["@mozilla.org/network/file-input-stream;1"].createInstance(Ci.nsIFileInputStream);
    input.init(file, 1, 0, 0);
    const reader = Cc["@mozilla.org/intl/converter-input-stream;1"].createInstance(Ci.nsIConverterInputStream);
    let text = "";
    try { reader.init(input, "UTF-8", 0, 0); const part = {}; while (reader.readString(4096, part)) text += part.value; }
    finally { reader.close(); input.close(); }
    const cfg = JSON.parse(text.replace(/^\uFEFF/, ""));
    if (cfg.enabled !== false || cfg.controllerUrl !== "http://127.0.0.1:9097" ||
        typeof cfg.token !== "string" || !cfg.token || /[\r\n]/.test(cfg.token)) {
      return JSON.stringify({ stage, result: "stop", reason: "disabled-local-config-required" });
    }
    stage = "api";
    const { ServiceRequest } = ChromeUtils.importESModule("resource://gre/modules/ServiceRequest.sys.mjs");
    const result = await new Promise(resolve => {
      xhr = new ServiceRequest({ mozAnon: true });
      xhr.open("GET", "http://127.0.0.1:9097/configs", { bypassProxy: true });
      if (!xhr.bypassProxy) { resolve({ result: "stop", reason: "direct-request-unavailable" }); return; }
      xhr.timeout = 1200;
      xhr.channel.notificationCallbacks = {
        QueryInterface: ChromeUtils.generateQI(["nsIInterfaceRequestor", "nsIChannelEventSink"]),
        getInterface(iid) { return this.QueryInterface(iid); },
        asyncOnChannelRedirect(_old, _new, _flags, cb) {
          resolve({ result: "stop", reason: "redirect-rejected" }); cb.onRedirectVerifyCallback(Cr.NS_ERROR_ABORT);
        }
      };
      xhr.setRequestHeader("Authorization", "Bearer " + cfg.token);
      xhr.onload = () => {
        if (xhr.status !== 200) { resolve({ result: "stop", httpStatus: xhr.status }); return; }
        try {
          if (xhr.responseText.length > 1048576) throw Error();
          const tun = JSON.parse(xhr.responseText)?.tun?.enable;
          resolve(typeof tun === "boolean" ? { result: "pass", httpStatus: 200, tunEnabled: tun } : { result: "stop", reason: "invalid-tun" });
        } catch { resolve({ result: "stop", reason: "invalid-response" }); }
      };
      xhr.onerror = () => resolve({ result: "stop", reason: "network-error" });
      xhr.ontimeout = () => resolve({ result: "stop", reason: "timeout" });
      xhr.onabort = () => resolve({ result: "stop", reason: "aborted" });
      xhr.onprogress = e => { if (e.loaded > 1048576) { resolve({ result: "stop", reason: "response-too-large" }); xhr.abort(); } };
      xhr.send();
    });
    return JSON.stringify({ stage, ...result, automaticSwitching: false });
  } catch { return JSON.stringify({ stage, result: "stop", reason: "diagnostic-exception" }); }
  finally { if (xhr) { xhr.onload = xhr.onerror = xhr.ontimeout = xhr.onabort = xhr.onprogress = null; try { xhr.abort(); } catch {} } }
})()
