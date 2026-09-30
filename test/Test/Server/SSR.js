export const readAllImpl = (stream) => () => new Response(stream).text();

