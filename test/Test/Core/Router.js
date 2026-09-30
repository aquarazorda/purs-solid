// Stands in for a dynamic `import()` of a module exporting `routes`.
export const loadRoutes = (routes) => () => new Promise((resolve) => setTimeout(() => resolve({ routes }), 2));
