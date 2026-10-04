// Compiles element calls in compiled PureScript (purs or purs-backend-es output)
// to JSX for Solid's compiler, so views get the same templates as Solid JSX.
// Each field is decoded from the element's props dictionary and keeps its
// runtime meaning; an element whose props or children aren't literal stays a
// runtime call.
import { parse } from "@babel/parser";
import generateModule from "@babel/generator";
import * as t from "@babel/types";
import { DOMWithState, SVGElements, VoidElements } from "@solidjs/web";

const generate = generateModule.default;

const helpers = ["childValue", "readValue", "fieldValue", "fieldProps", "fieldPart"];
const helper = (name) => t.identifier(`$$${name}`);

// Module names, with purs (`_`) and purs-backend-es (`$d`) escapes undone.
// The instances this reads are named in `Solid.Internal.Props`.
const unescape = (name) => name?.replace(/\$d/g, ".").replace(/_/g, ".");
const nameOf = (node) =>
  t.isMemberExpression(node)
    ? node.computed
      ? t.isStringLiteral(node.property) ? node.property.value : undefined
      : node.property.name
    : t.isIdentifier(node)
      ? node.name
      : undefined;
const moduleOf = (node) => (t.isMemberExpression(node) && t.isIdentifier(node.object) ? unescape(node.object.name) : undefined);

const reserved = new Set(["ado", "case", "class", "data", "derive", "do", "else", "false", "forall", "foreign", "if", "import",
  "in", "infix", "infixl", "infixr", "instance", "let", "module", "newtype", "of", "then", "true", "type", "where"]);
const tagOf = (name) => (name.endsWith("_") && reserved.has(name.slice(0, -1)) ? name.slice(0, -1) : name);

// Converters whose values are already what Solid sets.
const identityConverters = /^(identity|unsafeCoerce|attrValue(String|Int|Number|Boolean)|ariaValue(String|Int|Number))$/;

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

const returned = (fn) => {
  if (!t.isFunction(fn)) return undefined;
  if (!t.isBlockStatement(fn.body)) return fn.body;
  const [statement] = fn.body.body;
  return fn.body.body.length === 1 && t.isReturnStatement(statement) ? statement.argument : undefined;
};

const symbolLabel = (node) => {
  const property = t.isObjectExpression(node) && node.properties.find((p) => nameOf(p.key) === "reflectSymbol");
  const value = property && (t.isObjectMethod(property) ? property : property.value);
  const body = value && returned(value);
  return t.isStringLiteral(body) ? body.value : undefined;
};

// `import * as X from "../Module/index.js"`: X -> Module.
const importedModules = (ast) => {
  const out = new Map();
  for (const statement of ast.program.body) {
    const match = t.isImportDeclaration(statement) && statement.source.value.match(/^\.\.\/([^/]+)\/index\.js$/);
    const namespace = match && statement.specifiers.find((s) => t.isImportNamespaceSpecifier(s));
    if (namespace) out.set(namespace.local.name, match[1]);
  }
  return out;
};

// Modules whose converters and constructors the plugin may evaluate at build time.
export const constantModules = (code) =>
  [...new Set([...code.matchAll(/from "\.\.\/((?:DOM\.HTML\.Indexed\.\w+|Solid\.DOM\.AttrValue|Solid\.DOM\.Aria))\/index\.js"/g)].map((m) => m[1]))];

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

    // An application chain `f(a)(b)…`, following bindings and simple arrow
    // functions: the function it starts from and each argument list.
    const flatten = (node, seen = new Set()) => {
      node = resolve(node, seen);
      if (t.isCallExpression(node)) {
        const inner = flatten(node.callee, seen);
        const callee = inner.root;
        if (inner.args.length === 0 && t.isArrowFunctionExpression(callee) && callee.params.length === 1 && t.isIdentifier(callee.params[0])) {
          const body = returned(callee);
          if (body) return flatten(substitute(body, new Map([[callee.params[0].name, node.arguments[0]]])), seen);
        }
        return { root: callee, args: [...inner.args, node.arguments] };
      }
      return { root: node, args: [] };
    };
    const rootName = (chain) => nameOf(chain.root);
    const lastArgument = (chain) => chain.args.at(-1)?.[0];

    // label -> entry dictionary, from `propsRLCons(symbol)(entry)(rest)` chains.
    const fields = (dict) => {
      let list;
      const direct = resolve(dict);
      if (t.isObjectExpression(direct)) {
        list = direct.properties.find((p) => ["props", "untypedProps"].includes(nameOf(p.key)))?.value;
      } else if (["propsRecord", "untypedPropsRecord"].includes(rootName(flatten(dict)))) list = lastArgument(flatten(dict));
      if (!list) return undefined;
      const out = new Map();
      let node = list;
      for (;;) {
        node = resolve(node);
        if (t.isMemberExpression(node) && nameOf(node) === "propsRL") node = resolve(node.object);
        if ((t.isArrayExpression(node) && node.elements.length === 0) || nameOf(node) === "propsRLNil") return out;
        const chain = flatten(node);
        if (rootName(chain) !== "propsRLCons" || chain.args.length !== 3) return undefined;
        const label = symbolLabel(resolve(chain.args[0][0]));
        if (label === undefined) return undefined;
        out.set(label, chain.args[1][0]);
        node = chain.args[2][0];
      }
    };

    const nameArgument = (node) => {
      node = resolve(node);
      if (t.isStringLiteral(node)) return node.value;
      const chain = flatten(node);
      if (rootName(chain) === "attributeName" && t.isStringLiteral(lastArgument(chain))) return attributeName(lastArgument(chain).value);
      return undefined;
    };

    const member = (object, property) => t.memberExpression(object, t.identifier(property));
    const converter = (node) => (identityConverters.test(nameOf(node) ?? "") ? null : node);
    const attribute = (name, convert) => ({ kind: "attribute", name, convert: convert && converter(convert) });

    // purs: instances applied to instances.
    const decodeInstance = (label, dict) => {
      const chain = flatten(dict);
      const name = rootName(chain);
      const inner = (c) => flatten(lastArgument(c));
      switch (name) {
        case "entryRef":
          return { kind: "ref" };
        case "entryBindValue":
        case "entryBindChecked":
          return { kind: "bind", entry: member(dict, "entry") };
        case "entryInnerHTML":
        case "entryTextContent":
        case "entryRole":
          return attribute(label, null);
        case "entryClass":
        case "entryStyle":
          return rootName(inner(chain)) === `${label}ValueRecord` ? { kind: `${label}Record` } : attribute(label, null);
        case "entryPrefixed":
          break;
        default:
          return undefined;
      }
      const prefixed = inner(chain);
      switch (rootName(prefixed)) {
        case "prefixedData":
          return attribute(label, null);
        case "prefixedAria":
          return attribute(label, member(lastArgument(prefixed), "ariaValue"));
        case "prefixedEvent":
          return { kind: "event", name: "on" + label.slice(3) };
        case "prefixedAttribute": {
          const attr = inner(prefixed);
          if (rootName(attr) !== "attributeTyped") return undefined;
          const field = inner(attr);
          if (/^rowField\w*Event$/.test(rootName(field))) return { kind: "event", name: eventName(label) };
          if (rootName(field) === "rowFieldAttribute") return attribute(attributeName(label), member(lastArgument(field), "toAttrValue"));
        }
      }
      return undefined;
    };

    // purs-backend-es: instance bodies inlined as `{entry: …}`.
    const decodeEntry = (label, entry) => {
      const chain = flatten(entry);
      if (rootName(chain) === "bindingProp" && chain.args.length === 3) {
        const name = nameArgument(chain.args[1][0]);
        if (name !== undefined) return attribute(name, chain.args[2][0]);
      }
      if (t.isCallExpression(entry) && nameOf(entry.callee) === "field" && t.isMemberExpression(entry.callee) && t.isStringLiteral(entry.arguments[0])) {
        const fieldLabel = entry.arguments[0].value;
        const owner = entry.callee.object;
        if (/^rowField\w*Event$/.test(rootName(flatten(owner)) ?? "")) return { kind: "event", name: eventName(fieldLabel) };
        const instance = resolve(owner);
        const field = t.isObjectExpression(instance) && instance.properties.find((p) => nameOf(p.key) === "field");
        const body = field && returned(field.value);
        const inner = body && flatten(body);
        if (inner && rootName(inner) === "bindingProp" && inner.args.length === 3) return attribute(attributeName(fieldLabel), inner.args[2][0]);
      }
      if (t.isMemberExpression(entry)) {
        const owner = rootName(flatten(entry.object));
        if (nameOf(entry) === "classValue" && owner === "classValueRecord") return { kind: "classRecord" };
        if (nameOf(entry) === "styleValue" && owner === "styleValueRecord") return { kind: "styleRecord" };
        if (nameOf(entry) === "prefixed" && owner === "prefixedEvent") return { kind: "event", name: "on" + label.slice(3) };
      }
      return undefined;
    };

    const decode = (label, dict) => {
      const direct = resolve(dict);
      const entry = t.isObjectExpression(direct) && direct.properties.find((p) => nameOf(p.key) === "entry");
      return (entry ? decodeEntry(label, resolve(entry.value)) : decodeInstance(label, dict)) ??
        { kind: "field", entry: entry ? entry.value : member(dict, "entry") };
    };

    const childrenKind = (dict) => {
      if (dict === undefined) return "void";
      const direct = resolve(dict);
      if (t.isObjectExpression(direct)) {
        const source = generate(direct).code;
        return source.includes("textBindingImpl") ? "text" : source.includes("unsafeCoerce") ? "array" : undefined;
      }
      return { childrenArray: "array", childrenJSX: "jsx", childrenText: "text" }[rootName(flatten(dict))];
    };

    // `typedElement(props)(children)(ns)(tag)` / `typedVoidElement(props)(ns)(tag)`
    // (purs-backend-es), `Solid_DOM_HTML.tag(props)(children)` (purs).
    const element = (init) => {
      const chain = flatten(init);
      const name = rootName(chain);
      const { args } = chain;
      if (name === "typedElement" && args.length === 4) return { props: args[0][0], children: args[1][0], ns: args[2][0], tag: args[3][0] };
      if (name === "typedVoidElement" && args.length === 3) return { props: args[0][0], ns: args[1][0], tag: args[2][0] };
      const module = moduleOf(chain.root);
      if (module === "Solid.DOM.HTML" || module === "Solid.DOM.SVG") {
        const tag = tagOf(nameOf(chain.root));
        const ns = t.numericLiteral(module === "Solid.DOM.SVG" ? 1 : 0);
        const isVoid = module === "Solid.DOM.HTML" && VoidElements.has(tag);
        if (args.length === (isVoid ? 1 : 2)) return { props: args[0][0], children: args[1]?.[0], ns, tag: t.stringLiteral(tag) };
      }
      return undefined;
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
    return { elements, flatten, rootName, lastArgument };
  };

  const jsxAttribute = (name, value) =>
    t.jsxAttribute(name.includes(":") ? t.jsxNamespacedName(t.jsxIdentifier(name.split(":")[0]), t.jsxIdentifier(name.split(":")[1])) : t.jsxIdentifier(name), value);
  const container = (expression) => t.jsxExpressionContainer(expression);
  const call = (name, ...args) => t.callExpression(helper(name), args);
  const literalText = (node) => (t.isStringLiteral(node) ? node.value : t.isNumericLiteral(node) ? String(node.value) : undefined);
  const handler = (value, arg) => t.arrowFunctionExpression([arg], t.callExpression(t.callExpression(value, [arg]), []));
  const isPlainRecord = (node) => t.isObjectExpression(node) && node.properties.every((p) => t.isObjectProperty(p) && !p.computed);
  const record = (node) =>
    t.objectExpression(node.properties.map((p) =>
      t.objectProperty(p.key, t.isBooleanLiteral(p.value) || t.isStringLiteral(p.value) ? p.value : call("readValue", p.value))));
  const value = (node, convert) => (convert ? call("fieldValue", node, convert) : call("readValue", node));

  // JSX attributes for one element's literal props record. Stateful DOM
  // properties (`value`, `checked`) are attributes in server HTML.
  const attributes = (info, props, server, constant) => {
    const state = (name) => (server ? name : `prop:${name}`);
    if (!isPlainRecord(props)) return undefined;
    const out = [];
    for (const prop of props.properties) {
      const label = t.isIdentifier(prop.key) ? prop.key.name : t.isStringLiteral(prop.key) ? prop.key.value : undefined;
      const field = info.fields.get(label);
      if (field === undefined) return undefined;
      const v = prop.value;
      switch (field.kind) {
        case "attribute": {
          const { name, convert } = field;
          const text = convert ? constant(v, convert) : literalText(v);
          if (name === "style") out.push(jsxAttribute("style", container(value(v, convert))));
          else if (DOMWithState[info.tag.toUpperCase()]?.[name]) out.push(jsxAttribute(state(name), container(value(v, convert))));
          else if (text !== undefined) out.push(jsxAttribute(name, t.stringLiteral(text)));
          else if (t.isBooleanLiteral(v) && !convert) out.push(jsxAttribute(name, container(v)));
          else out.push(jsxAttribute(name, container(value(v, convert))));
          break;
        }
        case "event":
          out.push(jsxAttribute(field.name, container(handler(v, t.identifier("e")))));
          break;
        case "ref":
          out.push(jsxAttribute("ref", container(handler(v, t.identifier("el")))));
          break;
        case "classRecord":
        case "styleRecord":
          if (!isPlainRecord(v)) return undefined;
          out.push(jsxAttribute(field.kind === "classRecord" ? "class" : "style", container(record(v))));
          break;
        case "bind": {
          const [property, event] = label === "bindValue" ? ["value", "onInput"] : ["checked", "onChange"];
          out.push(jsxAttribute(state(property), container(call("fieldPart", field.entry, v, t.stringLiteral(property)))));
          if (!server) out.push(jsxAttribute(event, container(call("fieldPart", field.entry, t.cloneNode(v, true), t.stringLiteral(event)))));
          break;
        }
        default:
          out.push(t.jsxSpreadAttribute(call("fieldProps", field.entry, v)));
      }
    }
    return out;
  };

  return (code, { server = false, modules = new Map() } = {}) => {
    const ast = parse(code, { sourceType: "module" });
    const imported = importedModules(ast);

    // A converter applied to a literal or a nullary constructor, evaluated now
    // when both come from `modules` (see `constantModules`).
    const constant = (node, convert) => {
      const exported = (object, name) => (t.isIdentifier(object) ? modules.get(imported.get(object.name))?.[name] : undefined);
      if (!t.isMemberExpression(convert) || !t.isMemberExpression(convert.object)) return undefined;
      const fn = exported(convert.object.object, nameOf(convert.object))?.[nameOf(convert)];
      if (typeof fn !== "function") return undefined;
      let input;
      if (t.isStringLiteral(node) || t.isNumericLiteral(node) || t.isBooleanLiteral(node)) input = node.value;
      else if (t.isMemberExpression(node) && nameOf(node) === "value" && t.isMemberExpression(node.object)) {
        input = exported(node.object.object, nameOf(node.object))?.value;
      } else if (t.isMemberExpression(node)) input = exported(node.object, nameOf(node));
      if (input === undefined) return undefined;
      const result = fn(input);
      return typeof result === "string" || typeof result === "number" ? String(result) : undefined;
    };
    const { elements, flatten, rootName, lastArgument } = analyse(ast);
    if (elements.size === 0) return undefined;

    // `text(x)` (purs) / `textBindingImpl(x)` (purs-backend-es) in an array of children.
    const textChild = (node) => {
      if (!t.isCallExpression(node)) return undefined;
      const chain = flatten(node);
      const name = rootName(chain);
      const isText = name === "textBindingImpl" || (name === "text" && /JSX$/.test(moduleOf(chain.root) ?? ""));
      return isText ? container(lastArgument(chain)) : undefined;
    };

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
      const attrs = attributes(info, props, server, constant);
      if (attrs === undefined) return undefined;
      const inSvg = info.svg || info.tag === "svg";
      const childOf = (item) => convert(item, inSvg) ?? textChild(item) ?? container(call("childValue", item));
      const content = [];
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
    return { code: `import { ${imports} } from "../Solid.Internal.View/foreign.js";\n${generate(ast).code}`, rewritten };
  };
};

// The Vite plugin: compiles output modules that create elements. Servers use
// `generate: "ssr"`, browsers `"dom"`; `hydratable` when pages are server-rendered.
export const pursViews = ({ generate: mode, hydratable = false } = {}) => {
  let compile;
  return {
    name: "purs-solid:views",
    enforce: "pre",
    async transform(code, id, options) {
      if (!/[\\/]output(-es)?[\\/][^\\/]+[\\/]index\.js$/.test(id) || !/typedElement|Solid_DOM_(HTML|SVG)/.test(code)) return null;
      if (compile === undefined) {
        const names = await import(new URL("../Solid.Internal.Names/index.js", `file://${id}`).href);
        compile = compileViews(names);
      }
      const server = mode ? mode === "ssr" : (this.environment?.config.consumer ?? (options?.ssr ? "server" : "client")) === "server";
      const modules = new Map();
      for (const name of constantModules(code)) modules.set(name, await import(new URL(`../${name}/index.js`, `file://${id}`).href));
      const result = compile(code, { server, modules });
      if (result === undefined) return null;
      const { transformAsync } = await import("@solidjs/compiler");
      const compiled = await transformAsync(result.code, {
        generate: server ? "ssr" : "dom",
        hydratable,
        filename: id.replace(/\.js$/, ".jsx"),
        sourceMap: false,
      });
      return { code: compiled.code, map: null };
    },
  };
};
