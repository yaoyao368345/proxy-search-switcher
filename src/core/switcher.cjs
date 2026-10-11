(function (root) {
  "use strict";
  const { decide, unknown } = typeof module === "object" ? require("./state.cjs") : root.PSSState;
  function createSwitcher({ config, detectSystem, detectTun, search, timers, log = () => {} }) {
    let stopped = true, started = false, inFlight = null, timer = null, lastLog = "";
    function report(code) {
      if (lastLog !== code) { lastLog = code; log(code); }
    }
    async function run() {
      const safe = async fn => { try { return await fn(); } catch { return unknown("detector-failed"); } };
      const [system, tun] = await Promise.all([safe(detectSystem), safe(detectTun)]);
      if (stopped) return;
      const target = decide(system, tun);
      if (!target) { report(`hold:${system.reason}:${tun.reason}`); return; }
      const current = await search.getDefault();
      if (stopped) return;
      // Respect another engine chosen by a user or extension. Google/Bing remain managed.
      if (!["Google", "Bing"].includes(current?.name)) { report("hold:unmanaged-engine"); return; }
      if (current.name !== target) {
        const engine = search.getEngineByName(target);
        if (!engine || engine.hidden) { report("hold:engine-missing"); return; }
        // Recheck after awaiting current state to narrow the user-interaction race.
        const latest = await search.getDefault();
        if (stopped || latest?.name !== current.name) { report("hold:default-changed"); return; }
        await search.setDefault(engine, search.CHANGE_REASON.USER);
      }
      report(`default:${target}`);
    }
    function tick() {
      if (stopped) return Promise.resolve();
      if (inFlight) return inFlight;
      if (timer !== null) { timers.clearTimeout(timer); timer = null; }
      const began = Date.now();
      inFlight = run().catch(() => report("hold:search-error")).finally(() => {
        inFlight = null;
        // One timer for the parent process, no overlapping requests or queued ticks.
        if (!stopped) timer = timers.setTimeout(() => { timer = null; void tick(); },
          Math.max(0, config.intervalMs - (Date.now() - began)));
      });
      return inFlight;
    }
    async function start() {
      if (started || !config.enabled) return;
      started = true;
      stopped = false;
      try {
        await search.init();
        for (const name of ["Google", "Bing"]) {
          const engine = search.getEngineByName(name);
          if (!engine || engine.hidden) throw Error("missing-engine");
        }
        if (!stopped) await tick();
      } catch { stop(); report("stopped:search-incompatible"); }
    }
    function stop() {
      stopped = true;
      if (timer !== null) timers.clearTimeout(timer);
      timer = null;
    }
    return { start, stop, tick };
  }
  const api = { createSwitcher };
  if (typeof module === "object") module.exports = api;
  else root.PSSSwitcher = api;
})(globalThis);
