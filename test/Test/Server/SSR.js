export const readAllImpl = (stream) => () => new Response(stream).text();

export const loadNever = () => new Promise(() => {});
