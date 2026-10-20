"use strict";

const assert = require("node:assert/strict");

async function main() {
  const origin = process.env.FUNCTIONS_EMULATOR_ORIGIN ||
    "http://127.0.0.1:5001/demo-healthpocket/africa-south1";
  const response = await fetch(`${origin}/trustedBackend`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      data: { action: "wallet.ensure", payload: {} },
    }),
  });
  const body = await response.json();

  assert.equal(response.status, 401);
  assert.equal(body.error?.status, "UNAUTHENTICATED");
  assert.equal(body.error?.details?.code, "unauthenticated");
  assert.doesNotMatch(JSON.stringify(body), /stack|node_modules|functions\/src/i);
  process.stdout.write("Functions emulator callable boundary passed.\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
