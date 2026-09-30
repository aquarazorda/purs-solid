const parsed = new Map();

const parse = (pattern) => {
  let segments = parsed.get(pattern);
  if (segments === undefined) {
    segments = pattern
      .split("/")
      .filter((segment) => segment !== "")
      .map((segment) => {
        if (segment[0] === ":") {
          return segment.endsWith("?") ? { optional: segment.slice(1, -1) } : { param: segment.slice(1) };
        }
        if (segment[0] === "*" && segment.length > 1) return { rest: segment.slice(1) };
        return { text: segment };
      });
    parsed.set(pattern, segments);
  }
  return segments;
};

// Lone surrogates can't be encoded; keep them as they are.
const encode = (value) => {
  try {
    return encodeURIComponent(value);
  } catch {
    return value;
  }
};

export const hrefImpl = (toNullable, pattern, params) => {
  const out = [];
  for (const segment of parse(pattern)) {
    if (segment.text !== undefined) out.push(segment.text);
    else if (segment.param !== undefined) out.push(encode(params[segment.param]));
    else if (segment.rest !== undefined) out.push(params[segment.rest].split("/").map(encode).join("/"));
    else {
      const value = toNullable(params[segment.optional]);
      if (value !== null) out.push(encode(value));
    }
  }
  return "/" + out.join("/");
};
