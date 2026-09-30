const patterns = new Map();

// Segments of `/users/:id<int>/:tab?/*rest`, and the path Solid sees (filters removed).
export const routePattern = (pattern) => {
  let parsed = patterns.get(pattern);
  if (parsed === undefined) {
    const segments = pattern
      .split("/")
      .filter((segment) => segment !== "")
      .map((segment) => {
        const param = segment.match(/^([:*])([^<?]+)(?:<([a-z]+)>)?(\?)?$/);
        if (param === null || (param[1] === "*" && param[2] === "")) return { text: segment };
        return { name: param[2], rest: param[1] === "*", filter: param[3] ?? null, optional: param[4] === "?" };
      });
    const path = pattern.replace(/<[a-z]+>/g, "");
    parsed = { path, segments, params: segments.filter((segment) => segment.name !== undefined) };
    patterns.set(pattern, parsed);
  }
  return parsed;
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
  for (const segment of pattern.segments) {
    if (segment.text !== undefined) out.push(segment.text);
    else {
      const value = segment.optional ? toNullable(params[segment.name]) : params[segment.name];
      if (value === null) continue;
      if (segment.rest) out.push(String(value).split("/").map(encode).join("/"));
      else out.push(encode(String(value)));
    }
  }
  return "/" + out.join("/");
};
