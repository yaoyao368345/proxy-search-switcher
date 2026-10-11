(function (root) {
  "use strict";
  const { state, unknown } = typeof module === "object" ? require("./state.cjs") : root.PSSState;
  async function detectTun(config, request, readProcesses) {
    try {
      const response = await request(config);
      if (response.status === 401 || response.status === 403) return unknown("api-authentication");
      if (response.status !== 200) return unknown("api-http-error");
      let body;
      try { body = JSON.parse(response.text); } catch { return unknown("api-invalid-json"); }
      if (typeof body?.tun?.enable !== "boolean") return unknown("api-invalid-tun");
      return state(body.tun.enable ? "enabled" : "disabled", "api-confirmed");
    } catch (error) {
      // Timeout/auth/invalid JSON never prove shutdown. A refused connection AND
      // a complete native process snapshot without the configured core do.
      if (error?.code === "connection-refused") {
        try {
          const processes = readProcesses();
          if (processes && processes.every(v => !config.coreProcessNames.includes(v.toLowerCase()))) {
            return state("disabled", "core-absent-and-controller-refused");
          }
        } catch { /* keep unknown */ }
      }
      return unknown(error?.code === "timeout" ? "api-timeout" : "api-unreachable");
    }
  }
  const api = { detectTun };
  if (typeof module === "object") module.exports = api;
  else root.PSSMihomo = api;
})(globalThis);
