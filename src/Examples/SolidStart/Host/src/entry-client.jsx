// @refresh reload
import { StartClient, mount } from "@solidjs/start/client";

mount(() => <StartClient />, document.getElementById("app"));

if (typeof window !== "undefined") {
  window.__PURS_SOLID_START_CLIENT_READY__ = true;
}
