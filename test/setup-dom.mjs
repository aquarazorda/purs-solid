// Registers a DOM (happy-dom) as globals before the client test suite loads,
// so view tests render real elements in Node. Used via `node --import`.
import { GlobalRegistrator } from "@happy-dom/global-registrator";

GlobalRegistrator.register({ url: "http://localhost/" });
