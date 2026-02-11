import * as Data_Either from "/output/Data.Either/index.js";
import * as Data_Maybe from "/output/Data.Maybe/index.js";
import * as Solid_Component from "/output/Solid.Component/index.js";
import * as Solid_Control from "/output/Solid.Control/index.js";
import * as Solid_DOM from "/output/Solid.DOM/index.js";
import * as Solid_DOM_Events from "/output/Solid.DOM.Events/index.js";
import * as Solid_DOM_HTML from "/output/Solid.DOM.HTML/index.js";
import * as Solid_DOM_SVG from "/output/Solid.DOM.SVG/index.js";
import * as Solid_JSX from "/output/Solid.JSX/index.js";
import * as Solid_Lifecycle from "/output/Solid.Lifecycle/index.js";
import * as Solid_Reactivity from "/output/Solid.Reactivity/index.js";
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

    const memoDependencyDemo = Solid_Component.component(() => () => {
      const leftSignal = Solid_Signal.createSignal(1)();
      const left = leftSignal.value0;
      const setLeft = leftSignal.value1;

      const rightSignal = Solid_Signal.createSignal(10)();
      const right = rightSignal.value0;
      const setRight = rightSignal.value1;

      const memoRunsSignal = Solid_Signal.createSignal(0)();
      const memoRuns = memoRunsSignal.value0;
      const setMemoRuns = memoRunsSignal.value1;

      const memoValue = Solid_Reactivity.createMemo(() => {
        const currentLeft = left();
        Solid_Signal.modify(setMemoRuns)((n) => n + 1)();
        return currentLeft * 2;
      })();

      return Solid_DOM.div_([
        Solid_DOM.button({
          id: "memo-set-right",
          onClick: () => Solid_Signal.modify(setRight)((n) => n + 1)(),
        })([Solid_DOM.text("right")]),
        Solid_DOM.button({
          id: "memo-set-left",
          onClick: () => Solid_Signal.modify(setLeft)((n) => n + 1)(),
        })([Solid_DOM.text("left")]),
        Solid_DOM.span({ id: "memo-runs" })([() => String(memoRuns())]),
        Solid_DOM.span({ id: "memo-value" })([() => String(memoValue())]),
        Solid_DOM.span({ id: "memo-right" })([() => String(right())]),
      ]);
    });

    const memoDependencyRender = Solid_Web.render(
      () => Solid_Component.element(memoDependencyDemo)({})
    )(mount)();
    const memoDependencyDispose = expectRight("memo dependency demo renders", memoDependencyRender);

    const memoRunsNode = mount.querySelector("#memo-runs");
    const memoValueNode = mount.querySelector("#memo-value");
    const memoSetRightButton = mount.querySelector("#memo-set-right");
    const memoSetLeftButton = mount.querySelector("#memo-set-left");

    record("memo dependency initial runs", memoRunsNode?.textContent === "1", memoRunsNode?.textContent);
    record("memo dependency initial value", memoValueNode?.textContent === "2", memoValueNode?.textContent);

    if (memoSetRightButton instanceof HTMLButtonElement) {
      memoSetRightButton.click();
      record("memo ignores unrelated updates", memoRunsNode?.textContent === "1", memoRunsNode?.textContent);
      record("memo value stays stable on unrelated updates", memoValueNode?.textContent === "2", memoValueNode?.textContent);
    } else {
      record("memo-set-right button exists", false, memoSetRightButton);
    }

    if (memoSetLeftButton instanceof HTMLButtonElement) {
      memoSetLeftButton.click();
      record("memo recomputes on tracked updates", memoRunsNode?.textContent === "2", memoRunsNode?.textContent);
      record("memo value updates on tracked updates", memoValueNode?.textContent === "4", memoValueNode?.textContent);
    } else {
      record("memo-set-left button exists", false, memoSetLeftButton);
    }

    if (typeof memoDependencyDispose === "function") {
      memoDependencyDispose();
      record("memo dependency disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const effectCleanupDemo = Solid_Component.component(() => () => {
      const modeSignal = Solid_Signal.createSignal(0)();
      const mode = modeSignal.value0;
      const setMode = modeSignal.value1;

      const effectRunsSignal = Solid_Signal.createSignal(0)();
      const effectRuns = effectRunsSignal.value0;
      const setEffectRuns = effectRunsSignal.value1;

      const cleanupRunsSignal = Solid_Signal.createSignal(0)();
      const cleanupRuns = cleanupRunsSignal.value0;
      const setCleanupRuns = cleanupRunsSignal.value1;

      Solid_Reactivity.createEffect(() => {
        mode();
        Solid_Signal.modify(setEffectRuns)((n) => n + 1)();
        Solid_Lifecycle.onCleanup(() =>
          Solid_Signal.modify(setCleanupRuns)((n) => n + 1)()
        )();
      })();

      return Solid_DOM.div_([
        Solid_DOM.button({
          id: "effect-toggle",
          onClick: () => Solid_Signal.modify(setMode)((n) => n + 1)(),
        })([Solid_DOM.text("toggle")]),
        Solid_DOM.span({ id: "effect-runs" })([() => String(effectRuns())]),
        Solid_DOM.span({ id: "cleanup-runs" })([() => String(cleanupRuns())]),
      ]);
    });

    const effectCleanupRender = Solid_Web.render(
      () => Solid_Component.element(effectCleanupDemo)({})
    )(mount)();
    const effectCleanupDispose = expectRight("effect cleanup demo renders", effectCleanupRender);

    const effectRunsNode = mount.querySelector("#effect-runs");
    const cleanupRunsNode = mount.querySelector("#cleanup-runs");
    const effectToggleButton = mount.querySelector("#effect-toggle");

    record("effect cleanup initial effect run", effectRunsNode?.textContent === "1", effectRunsNode?.textContent);
    record("effect cleanup initial cleanup count", cleanupRunsNode?.textContent === "0", cleanupRunsNode?.textContent);

    if (effectToggleButton instanceof HTMLButtonElement) {
      effectToggleButton.click();
      record("effect reruns after dependency update", effectRunsNode?.textContent === "2", effectRunsNode?.textContent);
      record("cleanup runs before effect rerun", cleanupRunsNode?.textContent === "1", cleanupRunsNode?.textContent);
    } else {
      record("effect-toggle button exists", false, effectToggleButton);
    }

    if (typeof effectCleanupDispose === "function") {
      effectCleanupDispose();
      record("effect cleanup disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const domEventsDemo = Solid_Component.component(() => () => {
      const textSignal = Solid_Signal.createSignal("")();
      const textValue = textSignal.value0;
      const setTextValue = textSignal.value1;

      const checkedSignal = Solid_Signal.createSignal(false)();
      const checkedValue = checkedSignal.value0;
      const setCheckedValue = checkedSignal.value1;

      const eventTypeSignal = Solid_Signal.createSignal("")();
      const eventTypeValue = eventTypeSignal.value0;
      const setEventTypeValue = eventTypeSignal.value1;

      const keyboardMetaSignal = Solid_Signal.createSignal("")();
      const keyboardMetaValue = keyboardMetaSignal.value0;
      const setKeyboardMetaValue = keyboardMetaSignal.value1;

      const mouseMetaSignal = Solid_Signal.createSignal("")();
      const mouseMetaValue = mouseMetaSignal.value0;
      const setMouseMetaValue = mouseMetaSignal.value1;

      const parentKeyRunsSignal = Solid_Signal.createSignal(0)();
      const parentKeyRunsValue = parentKeyRunsSignal.value0;
      const setParentKeyRunsValue = parentKeyRunsSignal.value1;

      const onInput = Solid_DOM_Events.handler((event) => () => {
        const target = event.target;
        const value = target == null ? "" : String(target.value ?? "");

        Solid_Signal.set(setTextValue)(value)();
        Solid_Signal.set(setEventTypeValue)(String(event.type ?? ""))();
      });

      const onChange = Solid_DOM_Events.handler((event) => () => {
        const target = event.target;
        const checked = target != null && target.checked === true;

        Solid_Signal.set(setCheckedValue)(checked)();
        Solid_Signal.set(setEventTypeValue)(String(event.type ?? ""))();
      });

      const onKeyDown = Solid_DOM_Events.handler((event) => () => {
        event.preventDefault();
        event.stopPropagation();

        Solid_Signal.set(setEventTypeValue)(String(event.type ?? ""))();
        Solid_Signal.set(setKeyboardMetaValue)([
          String(event.key ?? ""),
          String(event.code ?? ""),
          String(event.repeat === true),
          String(event.ctrlKey === true),
          String(event.shiftKey === true),
          String(event.altKey === true),
          String(event.metaKey === true),
          String(event.defaultPrevented === true),
          String(event.bubbles === true),
          String(event.cancelable === true),
          String(event.target?.id ?? ""),
          String(event.currentTarget?.id ?? ""),
        ].join("|"))();
      });

      const onMouseDown = Solid_DOM_Events.handler((event) => () => {
        Solid_Signal.set(setEventTypeValue)(String(event.type ?? ""))();
        Solid_Signal.set(setMouseMetaValue)([
          String(event.clientX ?? ""),
          String(event.clientY ?? ""),
          String(event.screenX ?? ""),
          String(event.screenY ?? ""),
          String(event.button ?? ""),
          String(event.buttons ?? ""),
          String(event.detail ?? ""),
          String(event.target?.id ?? ""),
          String(event.currentTarget?.id ?? ""),
        ].join("|"))();
      });

      return Solid_DOM.div_([
        Solid_DOM.div({
          id: "event-parent",
          onKeyDown: Solid_DOM_Events.handler_(() =>
            Solid_Signal.modify(setParentKeyRunsValue)((n) => n + 1)()
          ),
        })([
          Solid_DOM.input({
            id: "event-keyboard",
            onKeyDown,
          })([]),
        ]),
        Solid_DOM.input({
          id: "event-input",
          value: () => textValue(),
          onInput,
        })([]),
        Solid_DOM.input({
          id: "event-checkbox",
          type: "checkbox",
          checked: () => checkedValue(),
          onChange,
        })([]),
        Solid_DOM.button({
          id: "event-mouse",
          onMouseDown,
        })([Solid_DOM.text("mouse")]),
        Solid_DOM.span({ id: "event-text" })([() => textValue()]),
        Solid_DOM.span({ id: "event-checked" })([() => String(checkedValue())]),
        Solid_DOM.span({ id: "event-type" })([() => eventTypeValue()]),
        Solid_DOM.span({ id: "event-keyboard-meta" })([() => keyboardMetaValue()]),
        Solid_DOM.span({ id: "event-mouse-meta" })([() => mouseMetaValue()]),
        Solid_DOM.span({ id: "event-parent-key-runs" })([() => String(parentKeyRunsValue())]),
      ]);
    });

    const domEventsRender = Solid_Web.render(
      () => Solid_Component.element(domEventsDemo)({})
    )(mount)();
    const domEventsDispose = expectRight("dom events demo renders", domEventsRender);

    const eventInput = mount.querySelector("#event-input");
    const eventCheckbox = mount.querySelector("#event-checkbox");
    const eventTextNode = mount.querySelector("#event-text");
    const eventCheckedNode = mount.querySelector("#event-checked");
    const eventTypeNode = mount.querySelector("#event-type");
    const eventKeyboardInput = mount.querySelector("#event-keyboard");
    const eventMouseButton = mount.querySelector("#event-mouse");
    const keyboardMetaNode = mount.querySelector("#event-keyboard-meta");
    const mouseMetaNode = mount.querySelector("#event-mouse-meta");
    const eventParentKeyRunsNode = mount.querySelector("#event-parent-key-runs");

    if (eventInput instanceof HTMLInputElement) {
      eventInput.value = "typed-value";
      eventInput.dispatchEvent(new Event("input", { bubbles: true }));

      record("targetValue reads input value", eventTextNode?.textContent === "typed-value", eventTextNode?.textContent);
      record("type_ records input event type", eventTypeNode?.textContent === "input", eventTypeNode?.textContent);
    } else {
      record("event input exists", false, eventInput);
    }

    if (eventCheckbox instanceof HTMLInputElement) {
      eventCheckbox.checked = true;
      eventCheckbox.dispatchEvent(new Event("change", { bubbles: true }));

      record("targetChecked reads checkbox state", eventCheckedNode?.textContent === "true", eventCheckedNode?.textContent);
      record("type_ records change event type", eventTypeNode?.textContent === "change", eventTypeNode?.textContent);
    } else {
      record("event checkbox exists", false, eventCheckbox);
    }

    if (eventKeyboardInput instanceof HTMLInputElement) {
      eventKeyboardInput.dispatchEvent(new KeyboardEvent("keydown", {
        bubbles: true,
        cancelable: true,
        key: "K",
        code: "KeyK",
        repeat: true,
        ctrlKey: true,
        shiftKey: true,
        altKey: false,
        metaKey: true,
      }));

      const keyboardMetaParts = (keyboardMetaNode?.textContent ?? "").split("|");
      record("keyboard key handling", keyboardMetaParts[0] === "K", keyboardMetaNode?.textContent);
      record("keyboard code handling", keyboardMetaParts[1] === "KeyK", keyboardMetaNode?.textContent);
      record("keyboard repeat handling", keyboardMetaParts[2] === "true", keyboardMetaNode?.textContent);
      record("keyboard modifier handling", keyboardMetaParts[3] === "true" && keyboardMetaParts[4] === "true" && keyboardMetaParts[5] === "false" && keyboardMetaParts[6] === "true", keyboardMetaNode?.textContent);
      record("preventDefault updates event object", keyboardMetaParts[7] === "true", keyboardMetaNode?.textContent);
      record("keyboard bubbles metadata", keyboardMetaParts[8] === "true", keyboardMetaNode?.textContent);
      record("keyboard cancelable metadata", keyboardMetaParts[9] === "true", keyboardMetaNode?.textContent);
      record("keyboard target ids metadata", keyboardMetaParts[10] === "event-keyboard" && keyboardMetaParts[11] === "event-keyboard", keyboardMetaNode?.textContent);
      record("keyboard event type recorded", eventTypeNode?.textContent === "keydown", eventTypeNode?.textContent);
      record("stopPropagation blocks parent key handler", eventParentKeyRunsNode?.textContent === "0", eventParentKeyRunsNode?.textContent);
    } else {
      record("event keyboard input exists", false, eventKeyboardInput);
    }

    if (eventMouseButton instanceof HTMLButtonElement) {
      eventMouseButton.dispatchEvent(new MouseEvent("mousedown", {
        bubbles: true,
        cancelable: true,
        clientX: 12,
        clientY: 34,
        screenX: 90,
        screenY: 91,
        button: 1,
        buttons: 4,
        detail: 2,
      }));

      const mouseMetaParts = (mouseMetaNode?.textContent ?? "").split("|");
      record("mouse client points handling", mouseMetaParts[0] === "12" && mouseMetaParts[1] === "34", mouseMetaNode?.textContent);
      record("mouse screen points handling", mouseMetaParts[2] === "90" && mouseMetaParts[3] === "91", mouseMetaNode?.textContent);
      record("mouse button handling", mouseMetaParts[4] === "1" && mouseMetaParts[5] === "4", mouseMetaNode?.textContent);
      record("mouse detail handling", mouseMetaParts[6] === "2", mouseMetaNode?.textContent);
      record("mouse target ids handling", mouseMetaParts[7] === "event-mouse" && mouseMetaParts[8] === "event-mouse", mouseMetaNode?.textContent);
      record("mouse event type recorded", eventTypeNode?.textContent === "mousedown", eventTypeNode?.textContent);
    } else {
      record("event mouse button exists", false, eventMouseButton);
    }

    if (typeof domEventsDispose === "function") {
      domEventsDispose();
      record("dom events disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const htmlSvgCoverageDemo = Solid_Component.component(() => () =>
      Solid_DOM_HTML.article({ id: "html-article" })([
        Solid_DOM_HTML.h2_([
          Solid_DOM.text("HTML coverage"),
        ]),
        Solid_DOM_HTML.dataTag({ id: "html-data", value: "42" })([
          Solid_DOM.text("42"),
        ]),
        Solid_DOM_SVG.svg({ id: "svg-root", viewBox: "0 0 20 20" })([
          Solid_DOM_SVG.circle({ id: "svg-circle", cx: "10", cy: "10", r: "4" })([]),
        ]),
      ]));

    const htmlSvgCoverageRender = Solid_Web.render(
      () => Solid_Component.element(htmlSvgCoverageDemo)({})
    )(mount)();
    const htmlSvgCoverageDispose = expectRight("html/svg constructor coverage demo renders", htmlSvgCoverageRender);

    const htmlArticle = mount.querySelector("#html-article");
    record("HTML constructor renders article tag", htmlArticle?.tagName === "ARTICLE", htmlArticle?.tagName);

    const htmlData = mount.querySelector("#html-data");
    record("HTML dataTag constructor renders data tag", htmlData?.tagName === "DATA", htmlData?.tagName);

    const svgRoot = mount.querySelector("#svg-root");
    record("SVG constructor renders svg tag", svgRoot?.tagName.toLowerCase() === "svg", svgRoot?.tagName);

    const svgCircle = mount.querySelector("#svg-circle");
    record("SVG constructor renders circle tag", svgCircle?.tagName.toLowerCase() === "circle", svgCircle?.tagName);

    if (typeof htmlSvgCoverageDispose === "function") {
      htmlSvgCoverageDispose();
      record("html/svg coverage disposer clears mount", mount.textContent === "", mount.textContent);
    }

    const controlDemo = Solid_Component.component(() => () => {
      const visibleSignal = Solid_Signal.createSignal(true)();
      const visible = visibleSignal.value0;
      const setVisible = visibleSignal.value1;

      const itemsSignal = Solid_Signal.createSignal(["alpha", "beta"])();
      const items = itemsSignal.value0;
      const setItems = itemsSignal.value1;

      const widget = Solid_Component.component(() => () =>
        Solid_DOM.div({ id: "dynamic-widget" })([
          Solid_DOM.text("widget"),
        ]));

      const addItem = () =>
        Solid_Signal.modify(setItems)((previous) =>
          previous.concat(`item-${previous.length}`)
        )();

      return Solid_DOM.div_([
        Solid_DOM.button({
          id: "toggle-visible",
          onClick: () => Solid_Signal.modify(setVisible)((value) => !value)(),
        })([
          Solid_DOM.text("toggle"),
        ]),
        Solid_Control.when(visible)(
          Solid_DOM.span({ id: "when-value" })([
            Solid_DOM.text("shown"),
          ])
        ),
        Solid_Control.whenElse(visible)(
          Solid_DOM.span({ id: "when-else-fallback" })([
            Solid_DOM.text("fallback"),
          ])
        )(
          Solid_DOM.span({ id: "when-else-content" })([
            Solid_DOM.text("content"),
          ])
        ),
        Solid_DOM.button({
          id: "add-item",
          onClick: addItem,
        })([
          Solid_DOM.text("add"),
        ]),
        Solid_DOM.ul({ id: "for-list" })([
          Solid_Control.forEach(items)((item) => () =>
            Solid_DOM.li_([
              Solid_DOM.text(item),
            ])
          ),
        ]),
        Solid_DOM.ul({ id: "for-index-list" })([
          Solid_Control.forEachWithIndex(items)((item) => (indexAccessor) => () =>
            Solid_DOM.li_([
              () => `${indexAccessor()}:${item}`,
            ])
          ),
        ]),
        Solid_DOM.ul({ id: "index-list" })([
          Solid_Control.indexEach(items)((itemAccessor) => () =>
            Solid_DOM.li_([
              () => String(itemAccessor()),
            ])
          ),
        ]),
        Solid_Control.switchCases([
          Solid_Control.matchWhenKeyed(visible)(
            Solid_DOM.div({ id: "switch-visible" })([
              Solid_DOM.text("switch shown"),
            ])
          ),
        ]),
        Solid_Control.dynamicTag("section")({
          id: "dynamic-tag",
          children: [Solid_DOM.text("dynamic tag")],
        }),
        Solid_Control.dynamicComponent(widget)({}),
      ]);
    });

    const controlRenderResult = Solid_Web.render(
      () => Solid_Component.element(controlDemo)({})
    )(mount)();
    const controlDispose = expectRight("control wrappers render", controlRenderResult);

    const whenValue = mount.querySelector("#when-value");
    record("when renders content when true", whenValue?.textContent === "shown", whenValue?.textContent);

    const whenElseContent = mount.querySelector("#when-else-content");
    record("whenElse renders content branch initially", whenElseContent?.textContent === "content", whenElseContent?.textContent);

    const forList = mount.querySelector("#for-list");
    record("forEach renders initial list length", forList?.children.length === 2, forList?.children.length);

    const indexList = mount.querySelector("#index-list");
    record("indexEach renders initial list length", indexList?.children.length === 2, indexList?.children.length);

    const forIndexList = mount.querySelector("#for-index-list");
    record("forEachWithIndex renders initial list length", forIndexList?.children.length === 2, forIndexList?.children.length);
    record("forEachWithIndex renders first item index", forIndexList?.children[0]?.textContent === "0:alpha", forIndexList?.children[0]?.textContent);

    const switchVisible = mount.querySelector("#switch-visible");
    record("switchCases renders matching branch", switchVisible?.textContent === "switch shown", switchVisible?.textContent);

    const dynamicTag = mount.querySelector("#dynamic-tag");
    record("dynamicTag renders requested element", dynamicTag?.tagName === "SECTION", dynamicTag?.tagName);

    const dynamicWidget = mount.querySelector("#dynamic-widget");
    record("dynamicComponent renders component", dynamicWidget?.textContent === "widget", dynamicWidget?.textContent);

    const addItemButton = mount.querySelector("#add-item");
    if (addItemButton instanceof HTMLButtonElement) {
      addItemButton.click();
      record("forEach updates after append", forList?.children.length === 3, forList?.children.length);
      record("indexEach updates after append", indexList?.children.length === 3, indexList?.children.length);
      record("forEachWithIndex updates after append", forIndexList?.children.length === 3, forIndexList?.children.length);
      record("forEachWithIndex renders appended index", forIndexList?.children[2]?.textContent === "2:item-2", forIndexList?.children[2]?.textContent);
    } else {
      record("add-item button exists", false, addItemButton);
    }

    const toggleVisibleButton = mount.querySelector("#toggle-visible");
    if (toggleVisibleButton instanceof HTMLButtonElement) {
      toggleVisibleButton.click();

      record("when hides content when false", mount.querySelector("#when-value") == null, mount.querySelector("#when-value"));

      const whenElseFallback = mount.querySelector("#when-else-fallback");
      record("whenElse renders fallback when false", whenElseFallback?.textContent === "fallback", whenElseFallback?.textContent);

      record("switchCases hides unmatched branch", mount.querySelector("#switch-visible") == null, mount.querySelector("#switch-visible"));
    } else {
      record("toggle-visible button exists", false, toggleVisibleButton);
    }

    if (typeof controlDispose === "function") {
      controlDispose();
      record("control disposer clears mount", mount.textContent === "", mount.textContent);
    }
  }

  const hydrateMount = document.getElementById("hydrate-root");
  record("hydrate test mount exists", hydrateMount != null, hydrateMount);

  if (hydrateMount != null) {
    const hydrateResult = Solid_Web.hydrate(
      () => Solid_DOM.div({ id: "hydrate-target" })([Solid_DOM.text("hydrated text")])
    )(hydrateMount)();
    if (isRight(hydrateResult)) {
      const hydrateDispose = hydrateResult.value0;
      const hydrateTarget = hydrateMount.querySelector("#hydrate-target");
      record("hydrate keeps expected text content", hydrateTarget?.textContent === "hydrated text", hydrateTarget?.textContent);
      record("hydrate returns Right disposer when hydration succeeds", typeof hydrateDispose === "function", hydrateDispose);

      if (typeof hydrateDispose === "function") {
        hydrateDispose();
        record("hydrate disposer is callable", true, "ok");
      }
    } else if (isLeft(hydrateResult) && hydrateResult.value0 instanceof Solid_Web.RuntimeError) {
      record("hydrate surfaces RuntimeError when hydration context is unavailable", true, hydrateResult.value0);
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
