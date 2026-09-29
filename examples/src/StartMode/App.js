export async function greetOnServer(name) {
  "use server";
  return `hello ${name}, from ${typeof window === "undefined" ? "the server" : "the browser"}`;
}
