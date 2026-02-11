import { createExamplesServer, startExamplesServer } from "./examples-server.mjs";

const asError = (error) => (error instanceof Error ? error : new Error(String(error)));

const main = async () => {
  const requestedPort = process.env.PORT == null ? 4173 : Number(process.env.PORT);
  const server = await createExamplesServer();
  const address = await startExamplesServer(server, requestedPort, "127.0.0.1");

  console.log(`[serve-examples] running at http://127.0.0.1:${address.port}/`);

  const shutdown = () => {
    server.close((error) => {
      if (error) {
        console.error(`[serve-examples] shutdown error: ${asError(error).message}`);
        process.exitCode = 1;
      }
    });
  };

  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
};

main().catch((error) => {
  console.error(`[serve-examples] ${asError(error).message}`);
  process.exitCode = 1;
});
