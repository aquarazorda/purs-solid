export const jsxValue = (jsx) => () => {
  let value = jsx;
  while (typeof value === "function") value = value();
  return Array.isArray(value) ? value.join("") : String(value);
};
