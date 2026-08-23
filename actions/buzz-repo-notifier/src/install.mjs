#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const defaultOptions = {
  action: "LorenzoTTGT/buzz-repo-notifier@main",
  workflowPath: ".github/workflows/notify-buzz.yml",
  targetDir: ".",
  ghConfig: true,
  commit: false,
  push: false,
  force: false,
  privateKeyStdin: false,
};

export function parseArgs(argv) {
  const options = { ...defaultOptions };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      const value = argv[++i];
      if (!value) throw new Error(`${arg} requires a value`);
      return value;
    };

    if (arg === "--repo") options.repo = next();
    else if (arg === "--relay-url") options.relayUrl = next();
    else if (arg === "--channel-id") options.channelId = next();
    else if (arg === "--channel-name") options.channelName = next();
    else if (arg === "--action") options.action = next();
    else if (arg === "--workflow-path") options.workflowPath = next();
    else if (arg === "--target-dir") options.targetDir = next();
    else if (arg === "--private-key-stdin") options.privateKeyStdin = true;
    else if (arg === "--no-gh-config") options.ghConfig = false;
    else if (arg === "--commit") options.commit = true;
    else if (arg === "--push") options.push = true;
    else if (arg === "--force") options.force = true;
    else if (arg === "--help" || arg === "-h") options.help = true;
    else throw new Error(`Unknown option: ${arg}`);
  }

  return options;
}

export function buildWorkflow(action) {
  return `name: Notify Buzz

on:
  push:
    branches: [main]
  issues:
    types: [opened]
  pull_request:
    types: [opened]

permissions:
  contents: read
  issues: read
  pull-requests: read

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: ${action}
        with:
          relay_url: \${{ vars.BUZZ_RELAY_URL }}
          channel_id: \${{ vars.BUZZ_CHANNEL_ID }}
          channel_name: \${{ vars.BUZZ_CHANNEL_NAME }}
          private_key: \${{ secrets.BUZZ_PRIVATE_KEY }}
`;
}

export async function install(options, runner = run) {
  if (options.help) {
    return { help: usage() };
  }

  if (options.ghConfig) {
    if (!options.repo) throw new Error("--repo owner/name is required unless --no-gh-config is used");
    if (!options.relayUrl) throw new Error("--relay-url is required unless --no-gh-config is used");
  }

  const workflowFile = resolve(options.targetDir, options.workflowPath);
  if (!options.force) {
    try {
      await readFile(workflowFile, "utf8");
      throw new Error(`${options.workflowPath} already exists; pass --force to overwrite it`);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }

  await mkdir(dirname(workflowFile), { recursive: true });
  await writeFile(workflowFile, buildWorkflow(options.action));

  let channelId = options.channelId;
  if (options.ghConfig) {
    const privateKey = await readPrivateKey(options);
    runner("gh", ["variable", "set", "BUZZ_RELAY_URL", "--repo", options.repo, "--body", options.relayUrl]);
    if (channelId) {
      runner("gh", ["variable", "set", "BUZZ_CHANNEL_ID", "--repo", options.repo, "--body", channelId]);
    }
    if (options.channelName) {
      runner("gh", ["variable", "set", "BUZZ_CHANNEL_NAME", "--repo", options.repo, "--body", options.channelName]);
    }
    runner("gh", ["secret", "set", "BUZZ_PRIVATE_KEY", "--repo", options.repo], { input: privateKey });
  }

  if (options.commit || options.push) {
    runner("git", ["-C", options.targetDir, "add", options.workflowPath]);
  }
  if (options.commit) {
    runner("git", ["-C", options.targetDir, "commit", "-m", "ci: notify Buzz on repository activity"]);
  }
  if (options.push) {
    runner("git", ["-C", options.targetDir, "push"]);
  }

  return { workflowFile, channelId };
}

async function readPrivateKey(options) {
  if (options.privateKeyStdin) {
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    const value = Buffer.concat(chunks).toString("utf8").trim();
    if (!value) throw new Error("No private key received on stdin");
    return value;
  }

  if (process.env.BUZZ_PRIVATE_KEY) return process.env.BUZZ_PRIVATE_KEY;
  throw new Error("Set BUZZ_PRIVATE_KEY or pass --private-key-stdin");
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    stdio: options.input ? ["pipe", "inherit", "inherit"] : "inherit",
    input: options.input,
    encoding: "utf8",
  });

  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")} failed with exit code ${result.status}`);
}

export function usage() {
  return `Usage: node src/install.mjs --repo owner/name --relay-url URL [--channel-id UUID | --channel-name NAME] [options]

Options:
  --repo owner/name        GitHub repository to configure with gh
  --relay-url URL          Buzz relay HTTP/WebSocket URL
  --channel-id UUID        Optional existing Buzz channel UUID
  --channel-name NAME      Optional channel name; defaults to the repository full name at runtime
  --action owner/repo@ref  Action reference to use in the workflow
                           default: LorenzoTTGT/buzz-repo-notifier@main
  --target-dir DIR         Local checkout where the workflow is written
                           default: .
  --workflow-path PATH     Workflow path inside target dir
                           default: .github/workflows/notify-buzz.yml
  --private-key-stdin      Read BUZZ_PRIVATE_KEY from stdin instead of env
  --no-gh-config           Only write the workflow file; do not call gh
  --force                  Overwrite an existing workflow file
  --commit                 Commit the workflow file after writing it
  --push                   Push after writing/committing
  -h, --help               Show this help

Examples:
  BUZZ_PRIVATE_KEY=nsec... node src/install.mjs \\
    --repo LorenzoTTGT/my-repo \\
    --relay-url https://buzz.example.com \\
    --channel-name buzz-repo-notifier \\
    --action LorenzoTTGT/buzz-repo-notifier@FULL_COMMIT_SHA \\
    --commit --push

  printf '%s' "$BUZZ_PRIVATE_KEY" | node src/install.mjs \\
    --repo LorenzoTTGT/my-repo \\
    --relay-url https://buzz.example.com \\
    --channel-id eb511182-5154-4631-b46b-3dd326293e4b \\
    --private-key-stdin
`;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  install(parseArgs(process.argv.slice(2)))
    .then((result) => {
      if (result.help) {
        console.log(result.help);
      } else {
        console.log(`Buzz notifier workflow written to ${result.workflowFile}`);
      }
    })
    .catch((error) => {
      console.error(error.message);
      console.error("Run with --help for usage.");
      process.exitCode = 1;
    });
}
