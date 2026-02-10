import * as Data_Either from "/output/Data.Either/index.js";
import * as Data_Maybe from "/output/Data.Maybe/index.js";
import * as Solid_Component from "/output/Solid.Component/index.js";
import * as Solid_DOM from "/output/Solid.DOM/index.js";
import * as Solid_JSX from "/output/Solid.JSX/index.js";
import * as Solid_Signal from "/output/Solid.Signal/index.js";
import * as Solid_Web from "/output/Solid.Web/index.js";

const failures = [];
let checks = 0;

const describe = (value) => {
  if (value == null) {
    return String(value);
  }

  if (typeof value === "string") {
    return value;
  }

  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }

  if (value.constructor && typeof value.constructor.name === "string") {
    if ("value0" in value) {
      return `${value.constructor.name}(${describe(value.value0)})`;
    }

    return value.constructor.name;
  }

  try {
    return JSON.stringify(value);
  } catch (_) {
    return String(value);
  }
};

const record = (label, condition, details) => {
  checks += 1;

  if (!condition) {
    failures.push({ label, details: describe(details) });
  }
};

const isRight = (value) => value instanceof Data_Either.Right;
const isLeft = (value) => value instanceof Data_Either.Left;
const isJust = (value) => value instanceof Data_Maybe.Just;

const expectRight = (label, value) => {
  if (isRight(value)) {
    record(label, true, "right");
    return value.value0;
  }

  record(label, false, value);
  return null;
};

const expectLeft = (label, value) => {
  if (isLeft(value)) {
    record(label, true, "left");
    return value.value0;
  }

  record(label, false, value);
  return null;
};

const setResult = () => {
  window.__PURS_SOLID_SMOKE_RESULT__ =
    failures.length === 0
      ? { ok: true, checks }
      : { ok: false, checks, failures };
};

const run = () => {
  record("isServer is false in browser", Solid_Web.isServer === false, Solid_Web.isServer);

  const bodyMaybe = Solid_Web.documentBody();
  record("documentBody returns Just", isJust(bodyMaybe), bodyMaybe);
  if (isJust(bodyMaybe)) {
    record("documentBody returns document.body", bodyMaybe.value0 === document.body, bodyMaybe.value0);
  }

  const mountMaybe = Solid_Web.mountById("app")();
  record("mountById returns Just for app", isJust(mountMaybe), mountMaybe);

  const requiredBody = Solid_Web.requireBody();
  const requiredBodyValue = expectRight("requireBody returns Right", requiredBody);
  if (requiredBodyValue != null) {
    record("requireBody returns document.body", requiredBodyValue === document.body, requiredBodyValue);
  }

  const requiredMount = Solid_Web.requireMountById("app")();
  const requiredMountValue = expectRight("requireMountById returns Right for app", requiredMount);

  const missingMount = Solid_Web.requireMountById("missing-node")();
  const missingMountError = expectLeft("requireMountById returns Left for missing id", missingMount);
  if (missingMountError != null) {
    record("missing id returns MissingMount", missingMountError instanceof Solid_Web.MissingMount, missingMountError);
  }

  const mount = requiredMountValue;

  if (mount != null) {
    const renderResult = Solid_Web.render(() => "browser smoke render")(mount)();
    const renderDispose = expectRight("render returns Right disposer", renderResult);

    record("render writes expected text", mount.textContent === "browser smoke render", mount.textContent);

    if (typeof renderDispose === "function") {
      renderDispose();
      record("render disposer clears mount text", mount.textContent === "", mount.textContent);
    } else {
      record("render disposer is callable", false, renderDispose);
    }

    const badgeComponent = Solid_Component.component((props) => () =>
      Solid_DOM.div({ id: props.id, className: props.className })([
        Solid_DOM.text(props.label),
      ])
    );

    const badgeView = Solid_Component.element(badgeComponent)({
      id: "component-badge",
      className: "badge",
      label: "component ok",
    });

    const componentRenderResult = Solid_Web.render(() => badgeView)(mount)();
    const componentRenderDispose = expectRight("component element renders via Solid.Component", componentRenderResult);
    const badgeElement = mount.querySelector("#component-badge");

    record("component render writes expected text", badgeElement?.textContent === "component ok", badgeElement?.textContent);

    if (typeof componentRenderDispose === "function") {
      componentRenderDispose();
      record("component disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const fragmentView = Solid_JSX.fragment([
      Solid_DOM.text("frag"),
      Solid_DOM.text("ment"),
    ]);

    const fragmentRenderResult = Solid_Web.render(() => fragmentView)(mount)();
    const fragmentRenderDispose = expectRight("fragment renders through Solid.JSX", fragmentRenderResult);
    record("fragment render combines children", mount.textContent === "fragment", mount.textContent);

    if (typeof fragmentRenderDispose === "function") {
      fragmentRenderDispose();
    }

    const keyedView = Solid_JSX.keyed("primary")(Solid_DOM.text("keyed"));
    const keyedRenderResult = Solid_Web.render(() => keyedView)(mount)();
    const keyedRenderDispose = expectRight("keyed JSX renders", keyedRenderResult);
    record("keyed render writes expected text", mount.textContent === "keyed", mount.textContent);

    if (typeof keyedRenderDispose === "function") {
      keyedRenderDispose();
      record("keyed disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const signalCounter = Solid_Component.component(() => () => {
      const signal = Solid_Signal.createSignal(0)();
      const count = signal.value0;
      const setCount = signal.value1;

      return Solid_DOM.element("button")({
        id: "signal-counter",
        onClick: () => Solid_Signal.modify(setCount)((n) => n + 1)(),
      })([
        () => String(count()),
      ]);
    });

    const signalCounterRender = Solid_Web.render(
      () => Solid_Component.element(signalCounter)({})
    )(mount)();
    const signalCounterDispose = expectRight("signal counter renders", signalCounterRender);
    const signalCounterButton = mount.querySelector("#signal-counter");

    record("signal counter starts at 0", signalCounterButton?.textContent === "0", signalCounterButton?.textContent);

    if (signalCounterButton instanceof HTMLButtonElement) {
      signalCounterButton.click();
      record("signal counter increments on click", signalCounterButton.textContent === "1", signalCounterButton.textContent);

      signalCounterButton.click();
      record("signal counter increments again", signalCounterButton.textContent === "2", signalCounterButton.textContent);
    } else {
      record("signal counter button exists", false, signalCounterButton);
    }

    if (typeof signalCounterDispose === "function") {
      signalCounterDispose();
    }

    const functionSignalCounter = Solid_Component.component(() => () => {
      const signal = Solid_Signal.createSignal(() => 0)();
      const readFn = signal.value0;
      const setFn = signal.value1;

      return Solid_DOM.element("button")({
        id: "fn-signal-counter",
        onClick: () =>
          Solid_Signal.modify(setFn)((fn) => () => fn() + 1)(),
      })([
        () => String(readFn()()),
      ]);
    });

    const functionSignalRender = Solid_Web.render(
      () => Solid_Component.element(functionSignalCounter)({})
    )(mount)();
    const functionSignalDispose = expectRight("function-valued signal counter renders", functionSignalRender);
    const fnCounterButton = mount.querySelector("#fn-signal-counter");

    record("function signal counter starts at 0", fnCounterButton?.textContent === "0", fnCounterButton?.textContent);

    if (fnCounterButton instanceof HTMLButtonElement) {
      fnCounterButton.click();
      record("function signal counter increments on click", fnCounterButton.textContent === "1", fnCounterButton.textContent);
    } else {
      record("function signal counter button exists", false, fnCounterButton);
    }

    if (typeof functionSignalDispose === "function") {
      functionSignalDispose();
      record("function signal disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const reducerCounter = Solid_Component.component(() => () => {
      const signal = Solid_Signal.createSignal(0)();
      const count = signal.value0;
      const setCount = signal.value1;

      const dispatch = (action) => {
        if (action === "Add") {
          return Solid_Signal.modify(setCount)((n) => n + 1)();
        }

        return Solid_Signal.modify(setCount)((n) => n - 1)();
      };

      return Solid_DOM.element("button")({
        id: "reducer-counter",
        onClick: () => dispatch("Add"),
      })([
        () => String(count()),
      ]);
    });

    const reducerRenderResult = Solid_Web.render(
      () => Solid_Component.element(reducerCounter)({})
    )(mount)();
    const reducerDispose = expectRight("reducer-style counter renders", reducerRenderResult);
    const reducerButton = mount.querySelector("#reducer-counter");

    record("reducer-style counter starts at 0", reducerButton?.textContent === "0", reducerButton?.textContent);

    if (reducerButton instanceof HTMLButtonElement) {
      reducerButton.click();
      reducerButton.click();
      record("reducer-style dispatch updates state", reducerButton.textContent === "2", reducerButton.textContent);
    } else {
      record("reducer-style counter button exists", false, reducerButton);
    }

    if (typeof reducerDispose === "function") {
      reducerDispose();
      record("reducer-style disposer clears mount", mount.textContent === "", mount.textContent);
    }
  }

  const hydrateMount = document.getElementById("hydrate-root");
  record("hydrate test mount exists", hydrateMount != null, hydrateMount);

  if (hydrateMount != null) {
    const hydrateResult = Solid_Web.hydrate(() => "hydrated text")(hydrateMount)();
    if (isRight(hydrateResult)) {
      const hydrateDispose = hydrateResult.value0;
      record("hydrate returns Right disposer when hydration succeeds", typeof hydrateDispose === "function", hydrateDispose);

      if (typeof hydrateDispose === "function") {
        hydrateDispose();
        record("hydrate disposer is callable", true, "ok");
      }
    } else if (isLeft(hydrateResult) && hydrateResult.value0 instanceof Solid_Web.RuntimeError) {
      record("hydrate surfaces RuntimeError for non-SSR mount", true, hydrateResult.value0);
    } else {
      record("hydrate returns expected Either shape", false, hydrateResult);
    }
  }
};

try {
  run();
} catch (error) {
  failures.push({
    label: "uncaught smoke exception",
    details: describe(error),
  });
}

setResult();
