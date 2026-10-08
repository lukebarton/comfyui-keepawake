// Tells the keepawake server routes when someone is actually using ComfyUI, so the Windows
// script can keep the PC awake. An open tab that nobody touches sends nothing: that's why this
// measures keyboard, mouse and touch input here rather than watching network traffic.
import { app } from "../../scripts/app.js";
import { api } from "../../scripts/api.js";

const PING_INTERVAL_MS = 60_000;
// Input within this window counts as the page being in use.
const ACTIVE_WINDOW_MS = 3 * 60_000;
const CHECK_INTERVAL_MS = 15_000;
const ACTIVITY_EVENTS = ["keydown", "mousedown", "mousemove", "wheel", "touchstart"];

let lastActivity = 0;
let lastPing = 0;

function inUse() {
  return document.visibilityState === "visible" && Date.now() - lastActivity < ACTIVE_WINDOW_MS;
}

// Called on every input event and on a timer, so the first input after a quiet spell is
// reported straight away and continued use is reported once a minute.
function maybePing() {
  if (!inUse() || Date.now() - lastPing < PING_INTERVAL_MS) return;
  lastPing = Date.now();
  api.fetchApi("/keepawake/ping", { method: "POST" }).catch((error) => {
    console.warn("[keepawake] ping failed", error);
  });
}

function onActivity() {
  lastActivity = Date.now();
  maybePing();
}

app.registerExtension({
  name: "keepawake",
  setup() {
    // Capture phase, so the graph canvas can't hide events by stopping their propagation.
    for (const type of ACTIVITY_EVENTS) {
      window.addEventListener(type, onActivity, { capture: true, passive: true });
    }
    setInterval(maybePing, CHECK_INTERVAL_MS);
  },
});
