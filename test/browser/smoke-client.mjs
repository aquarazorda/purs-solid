import * as Data_Either from "/output/Data.Either/index.js";
import * as Data_Maybe from "/output/Data.Maybe/index.js";
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
