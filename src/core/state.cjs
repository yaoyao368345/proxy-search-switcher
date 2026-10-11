(function (root) {
  "use strict";
  const state = (value, reason) => ({ state: value, reason });
  const unknown = reason => state("unknown", reason);
  function decide(system, tun) {
    // A proven enabled input is enough; disabled requires both proofs.
    if ([system.state, tun.state].includes("enabled")) return "Google";
    if (system.state === "disabled" && tun.state === "disabled") return "Bing";
    return null;
  }
  function classifySystem(snapshot, config) {
    if (!snapshot || !Number.isInteger(snapshot.flags)) return unknown("system-read-failed");
    const { flags, server = "", pac = "" } = snapshot;
    if (!(flags & 1) || (flags & ~15)) return unknown("unsupported-proxy-flags");
    // PAC and WPAD can route differently per URL; never attribute them to Clash.
    if (flags & 12) return unknown(flags & 4 ? "pac-active" : "auto-detect-active");
    if (!(flags & 2)) return state("disabled", "manual-proxy-off");
    if (pac) return unknown("inconsistent-pac-settings");
    const entries = server.toLowerCase().split(";").filter(Boolean).map(v => v.trim());
    const allowed = config.systemProxyServers.map(v => v.toLowerCase());
    if (!entries.length) return unknown("empty-proxy-server");
    let protocols = new Set();
    for (const item of entries) {
      const parts = item.split("=");
      if (parts.length === 1) {
        if (entries.length !== 1 || !allowed.includes(parts[0])) return unknown("foreign-proxy");
        return state("enabled", "matching-manual-proxy");
      }
      if (parts.length !== 2 || !["http", "https", "ftp", "socks"].includes(parts[0]) ||
          protocols.has(parts[0]) || !allowed.includes(parts[1])) return unknown("foreign-proxy");
      protocols.add(parts[0]);
    }
    return protocols.has("http") && protocols.has("https")
      ? state("enabled", "matching-manual-proxy") : unknown("partial-protocol-proxy");
  }
  function validateConfig(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw Error("invalid-config");
    const config = {
      enabled: true, intervalMs: 2000, timeoutMs: 1200, debug: false,
      controllerUrl: "http://127.0.0.1:9097", token: "",
      systemProxyServers: ["127.0.0.1:7897"],
      coreProcessNames: ["verge-mihomo.exe", "mihomo.exe", "clash-meta.exe"],
      ...raw,
    };
    for (const key of ["enabled", "debug"]) if (typeof config[key] !== "boolean") throw Error("invalid-config");
    for (const key of ["intervalMs", "timeoutMs"]) {
      if (!Number.isInteger(config[key]) || config[key] < 250 || config[key] > 60000) throw Error("invalid-config");
    }
    // Restrict credentials to a literal loopback address: no DNS, userinfo or redirects.
    if (typeof config.controllerUrl !== "string" ||
        !/^http:\/\/127\.0\.0\.1:(?:[1-9]\d{0,4})\/?$/.test(config.controllerUrl)) throw Error("invalid-controller-url");
    const port = Number(config.controllerUrl.match(/:(\d+)\/?$/)[1]);
    if (port > 65535) throw Error("invalid-controller-url");
    config.controllerUrl = config.controllerUrl.replace(/\/$/, "");
    if (typeof config.token !== "string" || /[\r\n]/.test(config.token)) throw Error("invalid-token");
    if (!Array.isArray(config.systemProxyServers) || !config.systemProxyServers.length ||
        config.systemProxyServers.some(v => typeof v !== "string" || !/^(127\.0\.0\.1|localhost):[1-9]\d{0,4}$/.test(v) || Number(v.split(":")[1]) > 65535)) throw Error("invalid-proxy-servers");
    if (!Array.isArray(config.coreProcessNames) || !config.coreProcessNames.length ||
        config.coreProcessNames.some(v => typeof v !== "string" || !/^[a-z0-9_-]+\.exe$/i.test(v))) throw Error("invalid-process-names");
    config.coreProcessNames = config.coreProcessNames.map(v => v.toLowerCase());
    return config;
  }
  const api = { state, unknown, decide, classifySystem, validateConfig };
  if (typeof module === "object") module.exports = api;
  else root.PSSState = api;
})(globalThis);
