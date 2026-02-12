const normalizeString = (value) => (typeof value === "string" ? value : "");

const encodePathSegment = (value) => encodeURIComponent(value);

export const routePathFromProps = (segments, props) => {
  const params = props?.params ?? {};
  const pathSegments = [];

  for (const segment of segments) {
    if (segment.kind === "static") {
      pathSegments.push(segment.value);
      continue;
    }

    if (segment.kind === "param") {
      const raw = normalizeString(params[segment.value]);
      if (raw.length === 0) {
        return "/";
      }
      pathSegments.push(encodePathSegment(raw));
      continue;
    }

    if (segment.kind === "optional") {
      const raw = normalizeString(params[segment.value]);
      if (raw.length > 0) {
        pathSegments.push(encodePathSegment(raw));
      }
      continue;
    }

    if (segment.kind === "catchAll") {
      const raw = normalizeString(params[segment.value]);
      if (raw.length > 0) {
        const pieces = raw.split("/").filter(Boolean);
        for (const piece of pieces) {
          pathSegments.push(encodePathSegment(piece));
        }
      }
    }
  }

  return pathSegments.length === 0 ? "/" : `/${pathSegments.join("/")}`;
};
