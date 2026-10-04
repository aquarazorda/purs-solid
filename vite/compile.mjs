// Compiles element calls in purs-backend-es output to JSX for Solid's compiler,
// so views get the same templates as Solid JSX. Each field is decoded from the
// element's props dictionary and keeps its runtime meaning; an element whose
// props or children aren't literal stays a runtime call.
import { parse } from "@babel/parser";
import generateModule from "@babel/generator";
import * as t from "@babel/types";
import { DOMWithState, SVGElements } from "@solidjs/web";

const generate = generateModule.default;

const helpers = ["childValue", "readValue", "fieldValue", "fieldProps"];
const helper = (name) => t.identifier(`$$${name}`);

const identityConverters = new Set(["identity", "unsafeCoerce"]);

const nameOf = (node) =>
  t.isMemberExpression(node) && !node.computed ? node.property.name : t.isIdentifier(node) ? node.name : undefined;

const callRoot = (node) => {
  while (t.isCallExpression(node)) node = node.callee;
  return node;
};

const callArguments = (node) => {
  const all = [];
  while (t.isCallExpression(node)) {
    all.unshift(node.arguments);
    node = node.callee;
  }
  return all;
};

// Replaces identifiers (not property names) with the expressions bound to them.
const substitute = (node, locals) => {
  if (Array.isArray(node)) return node.map((child) => substitute(child, locals));
  if (!node || typeof node.type !== "string") return node;
  if (t.isIdentifier(node) && locals.has(node.name)) return t.cloneNode(locals.get(node.name), true);
  const copy = { ...node };
  for (const key of t.VISITOR_KEYS[node.type] ?? []) {
    if ((key === "property" && t.isMemberExpression(node) && !node.computed) || (key === "key" && !node.computed)) continue;
    copy[key] = substitute(node[key], locals);
  }
  return copy;
};

// `(() => e)()`, and `(() => { const x = …; return e; })()` with the locals inlined.
const unwrapIife = (node) => {
  if (!t.isCallExpression(node) || node.arguments.length !== 0 || !t.isArrowFunctionExpression(node.callee)) return node;
  const body = node.callee.body;
  if (!t.isBlockStatement(body)) return body;
  const locals = new Map();
  for (const statement of body.body.slice(0, -1)) {
    if (!t.isVariableDeclaration(statement) || statement.declarations.length !== 1) return node;
    const [d] = statement.declarations;
    if (!t.isIdentifier(d.id) || !d.init) return node;
    locals.set(d.id.name, substitute(d.init, locals));
  }
  const last = body.body.at(-1);
  return t.isReturnStatement(last) && last.argument ? substitute(last.argument, locals) : node;
};

const symbolLabel = (node) => {
  const property = t.isObjectExpression(node) && node.properties.find((p) => nameOf(p.key) === "reflectSymbol");
  return property && t.isArrowFunctionExpression(property.value) && t.isStringLiteral(property.value.body)
    ? property.value.body.value
    : undefined;
};

export const compileViews = ({ attributeName, eventName }) => {
  const analyse = (ast) => {
    const decls = new Map();
    for (const statement of ast.program.body) {
      if (!t.isVariableDeclaration(statement)) continue;
      for (const d of statement.declarations) if (t.isIdentifier(d.id) && d.init) decls.set(d.id.name, d.init);
    }
    const resolve = (node, seen = new Set()) => {
      node = unwrapIife(node);
      if (t.isIdentifier(node) && decls.has(node.name) && !seen.has(node.name)) {
        seen.add(node.name);
        return resolve(decls.get(node.name), seen);
      }
      return node;
    };

    // label -> entry dictionary, from `propsRLCons(symbol)(entry)(rest).propsRL` chains.
    const fields = (dict) => {
      dict = resolve(dict);
      const list = t.isObjectExpression(dict) && dict.properties.find((p) => ["props", "untypedProps"].includes(nameOf(p.key)));
      if (!list) return undefined;
      const out = new Map();
      let node = list.value;
      for (;;) {
        node = resolve(node);
        if (t.isMemberExpression(node) && nameOf(node) === "propsRL") node = resolve(node.object);
        if (t.isArrayExpression(node) && node.elements.length === 0) return out;
        if (nameOf(node) === "propsRLNil") return out;
        const args = callArguments(node);
        if (nameOf(callRoot(node)) !== "propsRLCons" || args.length !== 3) return undefined;
        const label = symbolLabel(resolve(args[0][0]));
        if (label === undefined) return undefined;
        out.set(label, args[1][0]);
        node = args[2][0];
      }
    };

    const nameArgument = (node) => {
      node = resolve(node);
      if (t.isStringLiteral(node)) return node.value;
      if (t.isCallExpression(node) && nameOf(node.callee) === "attributeName" && t.isStringLiteral(node.arguments[0])) {
        return attributeName(node.arguments[0].value);
      }
      return undefined;
    };

    // What a field compiles to, from its entry dictionary.
    const decode = (label, dict) => {
      dict = resolve(dict);
      const entryProperty = t.isObjectExpression(dict) && dict.properties.find((p) => nameOf(p.key) === "entry");
      const instance = nameOf(callRoot(dict));
      if (instance === "entry$x34ref$x34") return { kind: "ref" };
      const entry = entryProperty ? resolve(entryProperty.value) : t.memberExpression(dict, t.identifier("entry"));
      const args = callArguments(entry);
      const root = nameOf(callRoot(entry));
      if (root === "bindingProp" && args.length === 3) {
        const name = nameArgument(args[1][0]);
        if (name !== undefined) return { kind: "attribute", name, convert: args[2][0] };
      }
      if (t.isCallExpression(entry) && t.isMemberExpression(entry.callee) && nameOf(entry.callee) === "field") {
        const fieldLabel = entry.arguments[0];
        const owner = entry.callee.object;
        if (/^rowField\w*Event$/.test(nameOf(callRoot(owner)) ?? "") && t.isStringLiteral(fieldLabel)) {
          return { kind: "event", name: eventName(fieldLabel.value) };
        }
        const instanceObject = resolve(owner);
        const field = t.isObjectExpression(instanceObject) && instanceObject.properties.find((p) => nameOf(p.key) === "field");
        if (field && t.isArrowFunctionExpression(field.value) && t.isStringLiteral(fieldLabel)) {
          const body = field.value.body;
          const inner = callArguments(body);
          if (nameOf(callRoot(body)) === "bindingProp" && inner.length === 3) {
            return { kind: "attribute", name: attributeName(fieldLabel.value), convert: inner[2][0] };
          }
        }
      }
      if (t.isMemberExpression(entry) && nameOf(entry) === "classValue" && nameOf(callRoot(entry.object)) === "classValueRecord") {
        return { kind: "classRecord" };
      }
      if (t.isMemberExpression(entry) && nameOf(entry) === "styleValue" && nameOf(callRoot(entry.object)) === "styleValueRecord") {
        return { kind: "styleRecord" };
      }
      if (t.isMemberExpression(entry) && nameOf(entry) === "prefixed" && nameOf(callRoot(entry.object)) === "prefixedFalseFalseTrue") {
        return { kind: "event", name: "on" + label.slice(3) };
      }
      return { kind: "field", entry };
    };

    // `typedElement(props)(children)(ns)(tag)` (or `typedVoidElement(props)(ns)(tag)`) in a binding.
    const element = (node, seen = new Set()) => {
      node = unwrapIife(node);
      if (t.isIdentifier(node) && decls.has(node.name) && !seen.has(node.name)) {
        seen.add(node.name);
        return element(decls.get(node.name), seen);
      }
      const args = callArguments(node);
      const root = nameOf(callRoot(node));
      if (root === "typedElement" && args.length === 4) {
        return { props: args[0][0], children: args[1][0], ns: args[2][0], tag: args[3][0] };
      }
      if (root === "typedVoidElement" && args.length === 3) {
        return { props: args[0][0], ns: args[1][0], tag: args[2][0], void: true };
      }
      // `const td1 = td(children)`, with `td = dictChildren => typedElement(props)(dictChildren)(0)("td")`.
      if (t.isCallExpression(node) && node.arguments.length === 1 && t.isIdentifier(node.callee)) {
        const partial = resolve(node.callee);
        if (t.isArrowFunctionExpression(partial) && partial.params.length === 1 && t.isIdentifier(partial.params[0])) {
          const inner = element(partial.body, seen);
          if (inner && t.isIdentifier(inner.children) && inner.children.name === partial.params[0].name) {
            return { ...inner, children: node.arguments[0] };
          }
        }
        if (t.isCallExpression(partial) || t.isMemberExpression(partial)) {
          const inner = element(t.callExpression(partial, node.arguments), seen);
          if (inner) return inner;
        }
      }
      // `typedElement(props)` partially applied, then `(children)(ns)(tag)` at the binding.
      if (args.length > 0 && t.isIdentifier(callRoot(node)) && decls.has(callRoot(node).name)) {
        const base = resolve(callRoot(node));
        if (base !== callRoot(node)) return element(args.reduce((f, a) => t.callExpression(f, a), base), seen);
      }
      return undefined;
    };

    const childrenKind = (dict) => {
      if (dict === undefined) return "void";
      if (nameOf(resolve(dict)) === "childrenJSX" || nameOf(dict) === "childrenJSX") return "jsx";
      const source = generate(resolve(dict)).code;
      return source.includes("textBindingImpl") ? "text" : source.includes("unsafeCoerce") ? "array" : undefined;
    };

    const elements = new Map();
    for (const [name, init] of decls) {
      const found = element(init);
      if (!found || !t.isNumericLiteral(found.ns) || !t.isStringLiteral(found.tag)) continue;
      const props = fields(found.props);
      const kind = childrenKind(found.children);
      if (props === undefined || kind === undefined) continue;
      const decoded = new Map([...props].map(([label, dict]) => [label, decode(label, dict)]));
      elements.set(name, { tag: found.tag.value, svg: found.ns.value === 1, kind, fields: decoded });
    }
    return elements;
  };

  const attribute = (name, value) => t.jsxAttribute(t.jsxIdentifier(name), value);
  const container = (expression) => t.jsxExpressionContainer(expression);
  const call = (name, ...args) => t.callExpression(helper(name), args);
  const isIdentityConverter = (node) => identityConverters.has(nameOf(node));
  const literalText = (node) =>
    t.isStringLiteral(node) ? node.value : t.isNumericLiteral(node) ? String(node.value) : undefined;

  const effectHandler = (value, arg) =>
    t.arrowFunctionExpression([arg], t.callExpression(t.callExpression(value, [arg]), []));

  const recordValues = (node, read) =>
    t.objectExpression(node.properties.map((p) =>
      t.objectProperty(p.key, t.isBooleanLiteral(p.value) || t.isStringLiteral(p.value) ? p.value : read(p.value))));

  const isPlainRecord = (node) =>
    t.isObjectExpression(node) && node.properties.every((p) => t.isObjectProperty(p) && !p.computed);

  // JSX attributes for one element's literal props record.
  const attributes = (info, props) => {
    if (!isPlainRecord(props)) return undefined;
    const out = [];
    for (const prop of props.properties) {
      const label = t.isIdentifier(prop.key) ? prop.key.name : t.isStringLiteral(prop.key) ? prop.key.value : undefined;
      const field = info.fields.get(label);
      if (field === undefined) return undefined;
      const value = prop.value;
      switch (field.kind) {
        case "attribute": {
          const { name, convert } = field;
          const text = literalText(value);
          if (name === "style") out.push(attribute("style", container(call("fieldValue", value, convert))));
          else if (DOMWithState[info.tag.toUpperCase()]?.[name]) {
            out.push(t.jsxAttribute(t.jsxNamespacedName(t.jsxIdentifier("prop"), t.jsxIdentifier(name)), container(call("fieldValue", value, convert))));
          } else if (text !== undefined && isIdentityConverter(convert)) out.push(attribute(name, t.stringLiteral(text)));
          else if (t.isBooleanLiteral(value) && isIdentityConverter(convert)) out.push(attribute(name, container(value)));
          else out.push(attribute(name, container(call("fieldValue", value, convert))));
          break;
        }
        case "event":
          out.push(attribute(field.name, container(effectHandler(value, t.identifier("e")))));
          break;
        case "ref":
          out.push(attribute("ref", container(effectHandler(value, t.identifier("el")))));
          break;
        case "classRecord":
          if (!isPlainRecord(value)) return undefined;
          out.push(attribute("class", container(recordValues(value, (v) => call("readValue", v)))));
          break;
        case "styleRecord":
          if (!isPlainRecord(value)) return undefined;
          out.push(attribute("style", container(recordValues(value, (v) => call("readValue", v)))));
          break;
        default:
          out.push(t.jsxSpreadAttribute(call("fieldProps", field.entry, value)));
      }
    }
    return out;
  };

  const textChild = (node) => {
    if (t.isCallExpression(node) && nameOf(node.callee) === "textBindingImpl" && node.arguments.length === 1) {
      const [value] = node.arguments;
      return t.isStringLiteral(value) ? container(value) : container(value);
    }
    return undefined;
  };

  return (code) => {
    const ast = parse(code, { sourceType: "module" });
    const elements = analyse(ast);
    if (elements.size === 0) return undefined;

    const convert = (node, parentSvg) => {
      if (!t.isCallExpression(node)) return undefined;
      let info, props, children;
      if (t.isCallExpression(node.callee) && t.isIdentifier(node.callee.callee) && node.callee.arguments.length === 1 && node.arguments.length === 1) {
        info = elements.get(node.callee.callee.name);
        if (info?.kind === "void") return undefined;
        props = node.callee.arguments[0];
        children = node.arguments[0];
      } else if (t.isIdentifier(node.callee) && node.arguments.length === 1) {
        info = elements.get(node.callee.name);
        if (info?.kind !== "void") return undefined;
        props = node.arguments[0];
      }
      if (info === undefined) return undefined;
      // A root SVG element needs a tag Solid knows is SVG; HTML can't sit inside SVG here.
      if (info.svg ? !parentSvg && !SVGElements.has(info.tag) : parentSvg) return undefined;
      const attrs = attributes(info, props);
      if (attrs === undefined) return undefined;
      const content = [];
      const childOf = (item) => convert(item, info.svg || info.tag === "svg") ?? textChild(item) ?? container(call("childValue", item));
      if (info.kind === "array") {
        if (!t.isArrayExpression(children)) return undefined;
        for (const item of children.elements) content.push(childOf(item));
      } else if (info.kind === "text") content.push(container(children));
      else if (info.kind === "jsx") content.push(childOf(children));
      const name = t.jsxIdentifier(info.tag);
      const empty = info.kind === "void";
      return t.jsxElement(t.jsxOpeningElement(name, attrs, empty), empty ? null : t.jsxClosingElement(name), content, empty);
    };

    let rewritten = 0;
    const visit = (node) => {
      if (Array.isArray(node)) return node.map(visit);
      if (!node || typeof node.type !== "string") return node;
      const jsx = convert(node, false);
      if (jsx !== undefined) {
        rewritten += 1;
        return t.arrowFunctionExpression([], visit(jsx));
      }
      for (const key of t.VISITOR_KEYS[node.type] ?? []) node[key] = visit(node[key]);
      return node;
    };
    ast.program = visit(ast.program);
    if (rewritten === 0) return undefined;
    const imports = helpers.map((name) => `${name} as $$${name}`).join(", ");
    return {
      code: `import { ${imports} } from "../Solid.Internal.View/foreign.js";\n${generate(ast).code}`,
      rewritten,
    };
  };
};

// The Vite plugin: compiles purs-backend-es output modules that create elements.
export const pursViews = ({ generate: mode = "dom", hydratable = false } = {}) => {
  let compile;
  return {
    name: "purs-solid:views",
    enforce: "pre",
    async transform(code, id) {
      if (!/\/output-es\/[^/]+\/index\.js$/.test(id) || !code.includes("typedElement")) return null;
      if (compile === undefined) {
        const names = await import(new URL("../Solid.Internal.Names/index.js", `file://${id}`).href);
        compile = compileViews(names);
      }
      const result = compile(code);
      if (result === undefined) return null;
      const { transformAsync } = await import("@solidjs/compiler");
      const compiled = await transformAsync(result.code, { generate: mode, hydratable, filename: id.replace(/\.js$/, ".jsx"), sourceMap: false });
      return { code: compiled.code, map: null };
    },
  };
};
