import { spawn } from "node:child_process";

const processes = [
  spawn("npm", ["run", "api"], { stdio: "inherit" }),
  spawn("npm", ["run", "web"], { stdio: "inherit" })
];

for (const child of processes) {
  child.on("exit", (code) => {
    if (code && code !== 0) {
      shutdown(code);
    }
  });
}

process.on("SIGINT", () => shutdown(0));
process.on("SIGTERM", () => shutdown(0));

function shutdown(code: number): void {
  for (const child of processes) {
    if (!child.killed) {
      child.kill();
    }
  }
  process.exit(code);
}
