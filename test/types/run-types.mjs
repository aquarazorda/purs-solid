// Element props the type checker must accept or reject. Each rejected case is
// its own module, compiled in one `purs` run against the built library.
import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { checks, rootDir } from "../support.mjs";

const { expect, report } = checks("types");

const imports = `import Prelude
import DOM.HTML.Indexed.InputType (InputType(..))
import Solid.DOM (element)
import Solid.DOM.Aria as Aria
import Solid.DOM.HTML as H
import Solid.DOM.SVG as S
import Solid.JSX (JSX, text)
import Solid.Meta as Meta
import Solid.Signal (Accessor, Signal)
import Web.HTML.HTMLInputElement (HTMLInputElement)
import Web.HTML.HTMLInputElement as Input
import Web.UIEvent.KeyboardEvent (KeyboardEvent)
import Web.UIEvent.KeyboardEvent as KeyboardEvent
import Web.UIEvent.MouseEvent (MouseEvent)
`;

const accepted = [
  ["Accessor String -> Accessor Boolean -> JSX", `\\label disabled -> H.div { "data-id": label, role: "group", "aria-label": label, "aria-hidden": disabled, "aria-level": 2, "aria-valuenow": 0.5, "aria-checked": Aria.Mixed, "aria-live": Aria.Polite, "aria-relevant": Aria.All }
  [ H.input { ref: \\input -> void (Input.value input), type: InputText, value: label, disabled, onKeyDown: \\event -> void (pure (KeyboardEvent.key event)) }
  , H.label { for: "name", class: { active: disabled, static: true }, style: { color: label } } label
  , H.td { colSpan: 2, "on:custom": \\_ -> pure unit } []
  , S.svg { viewBox: "0 0 1 1" } (S.path { d: "M0", strokeWidth: "2" } [])
  , element "x-widget" { count: 2, onPing: \\_ -> pure unit } [ text "a", H.br {} ]
  ]`],
  ["Signal String -> Signal Boolean -> JSX", `\\name done -> H.div {}
  [ H.input { bindValue: name }, H.textarea { bindValue: name } [], H.input { type: InputCheckbox, bindChecked: done } ]`],
  ["JSX", `Meta.meta { key: "image-1", name: "og:image", content: "a.png" }`],
];

// [why, type, expression, a fragment of the error]
const rejected = [
  ["an attribute the element doesn't have", "JSX", `H.div { href: "/" } []`, "href"],
  ["a value of the wrong type", "JSX", `H.button { disabled: "yes" } []`, "ToBinding String Boolean"],
  ["a string where the row has a value type", "JSX", `H.input { type: "text" }`, "ToBinding String InputType"],
  ["an accessor of the wrong type", "Accessor Int -> JSX", `\\n -> H.p { title: n } []`, "ToBinding (Accessor Int) String"],
  ["an SVG attribute of the wrong type", "JSX", `S.svg { viewBox: 1 } []`, "ToBinding Int String"],
  ["a handler for another event type", "JSX", `H.button { onClick: \\(_ :: KeyboardEvent) -> pure unit } []`, "MouseEvent"],
  ["a ref typed as another element", "JSX", `H.div { ref: \\(_ :: HTMLInputElement) -> pure unit } []`, "HTMLDivElement"],
  ["a ref on a tag without an element", "JSX", `Meta.meta { ref: \\_ -> pure unit }`, "$element"],
  ["bindValue on an element without a value", "Signal String -> JSX", `\\s -> H.div { bindValue: s } []`, "value"],
  ["bindValue with a non-string signal", "Signal Int -> JSX", `\\s -> H.input { bindValue: s }`, "Int"],
  ["a class toggle that isn't a boolean", "JSX", `H.div { class: { active: "yes" } } []`, "ToBinding String Boolean"],
  ["a data attribute that isn't a string", "JSX", `H.div { "data-count": 1 } []`, "ToBinding Int String"],
  ["an aria attribute that doesn't exist", "JSX", `H.div { "aria-labeled": "x" } []`, "aria-labeled"],
  ["a string for an aria boolean", "JSX", `H.div { "aria-hidden": "true" } []`, "Could not match type String with type Boolean"],
  ["a string for an aria number", "JSX", `H.div { "aria-level": "2" } []`, "Could not match type String with type Int"],
  ["a string for an aria keyword", "JSX", `H.div { "aria-checked": "mixed" } []`, "Could not match type String with type Tristate"],
  ["a keyword from another attribute", "JSX", `H.div { "aria-live": Aria.Mixed } []`, "Could not match type Tristate with type Live"],
  ["a string for aria-relevant", "JSX", `H.div { "aria-relevant": "additions text" } []`, "Could not match type String with type Relevant"],
  ["an empty aria-relevant", "JSX", `H.div { "aria-relevant": [] } []`, "with type Relevant"],
  ["a combined aria-relevant", "JSX", `H.div { "aria-relevant": Aria.Additions <> Aria.Additions } []`, "Semigroup Relevant"],
  ["an on: handler for a specific event type", "JSX", `H.div { "on:ping": \\(_ :: MouseEvent) -> pure unit } []`, "MouseEvent"],
  ["text mixed into an array of elements", "JSX", `H.div {} [ "a", H.span {} "b" ]`, "JSX"],
];

const moduleSource = (name, cases) =>
  `module ${name} where\n\n${imports}\n${cases.map(([type, expression], i) => `x${i} :: ${type}\nx${i} = ${expression}\n`).join("\n")}`;

const dir = mkdtempSync(join(tmpdir(), "purs-solid-types-"));
try {
  cpSync(join(rootDir, "output"), join(dir, "output"), { recursive: true });
  writeFileSync(join(dir, "Accepted.purs"), moduleSource("Types.Accepted", accepted));
  rejected.forEach(([, type, expression], i) => writeFileSync(join(dir, `Rejected${i}.purs`), moduleSource(`Types.Rejected${i}`, [[type, expression]])));

  let output = "";
  try {
    execFileSync(join(rootDir, "node_modules", ".bin", "purs"), ["compile", ".spago/p/*/src/**/*.purs", "src/**/*.purs", join(dir, "*.purs"), "-o", join(dir, "output")], {
      cwd: rootDir,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    output = error.stdout;
  }

  const errors = new Map();
  for (const block of output.split(/^Error (?:found|\d+ of \d+):$/m).slice(1)) {
    const module = block.match(/in module (\S+)/)?.[1];
    if (module) errors.set(module, block.replace(/\s+/g, " "));
  }

  expect("accepted cases compile", errors.get("Types.Accepted") ?? null, null);
  rejected.forEach(([why, , , fragment], i) => {
    const error = errors.get(`Types.Rejected${i}`) ?? "";
    expect(`rejects ${why}`, error.includes(fragment) ? "rejected" : error || "compiled", "rejected");
  });
} finally {
  rmSync(dir, { recursive: true, force: true });
}
report();
