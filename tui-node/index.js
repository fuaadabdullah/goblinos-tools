#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const prompts = require("prompts");
let execa = require("execa");
// Normalize export shape across execa versions (CommonJS/ESM interop)
if (typeof execa !== "function") {
  if (execa && typeof execa.default === "function") {
    execa = execa.default;
  } else if (execa && typeof execa.execa === "function") {
    execa = execa.execa;
  } else {
    throw new Error("Unsupported execa export shape; unable to run shell commands")
  }
}

function loadConfig(p) {
  const pth = p || path.resolve(__dirname, "../tui/config.json");
  try {
    const resolved = path.resolve(pth);
    const raw = fs.readFileSync(resolved, "utf8");
    return JSON.parse(raw);
  } catch (err) {
    console.error(`Failed to load config ${pth}: ${err.message}`);
    process.exit(2);
  }
}

async function chooseCommand(commands) {
  const choices = Object.keys(commands).map((k) => ({ title: k, value: k }));
  const response = await prompts({
    type: "select",
    name: "cmd",
    message: "Select a Goblin command",
    choices,
  });
  return response.cmd;
}

async function run() {
  const argvConfigIndex = process.argv.indexOf("--config");
  const cfgPath = argvConfigIndex >= 0 ? process.argv[argvConfigIndex + 1] : undefined;
  const cfg = loadConfig(cfgPath);

  const commands = cfg.commands || {};
  if (Object.keys(commands).length === 0) {
    console.error("No commands found in config. Copy tools/tui/config.json.example to tools/tui/config.json and edit.");
    process.exit(1);
  }

  let key;
  if (process.env.GOBLIN_CMD) {
    // allow non-interactive selection for tests: name of command or numeric index (1-based)
    const g = process.env.GOBLIN_CMD;
    if (/^\d+$/.test(g)) {
      const idx = parseInt(g, 10) - 1;
      key = Object.keys(commands)[idx];
    } else {
      key = g;
    }
    if (!key || !commands[key]) {
      console.error(`GOBLIN_CMD=${g} did not match any command`);
      process.exit(3);
    }
  } else {
    key = await chooseCommand(commands);
  }
  if (!key) {
    console.log("No selection, exiting.");
    process.exit(0);
  }

  const cmd = commands[key];
  const cwdTemplate = cfg.cwd || "${repo_root}";
  let cwd = cwdTemplate;
  if (cwd && cwd.includes("${repo_root}")) {
    // repo root default: two directories up from tools/tui-node
    const repoRoot = path.resolve(__dirname, "..", "..");
    cwd = cwd.replace("${repo_root}", repoRoot);
  }

  console.log(`Running: ${cmd}\nWorking dir: ${cwd}`);

  try {
  // Use execa(...) with shell:true for broad compatibility across execa versions
  const subprocess = execa(cmd, { shell: true, cwd });

  if (subprocess.stdout) subprocess.stdout.pipe(process.stdout);
  if (subprocess.stderr) subprocess.stderr.pipe(process.stderr);

  const result = await subprocess;
  // execa returns exitCode in `exitCode` or `code` depending on version; handle both
  const code = result.exitCode ?? result.code ?? 0;
  console.log(`\nCommand exited with code ${code}`);
  } catch (err) {
    if (err.exitCode !== undefined) {
      console.error(`\nCommand failed with exit code ${err.exitCode}`);
    } else {
      console.error(`\nCommand error: ${err}`);
    }
    process.exit(err.exitCode || 1);
  }
}

run();
