import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { buildWorkflow, install, parseArgs } from "../src/install.mjs";

test("parses installer options", () => {
  const options = parseArgs([
    "--repo", "acme/music",
    "--relay-url", "https://buzz.example.com",
    "--channel-name", "buzz-repo-notifier",
    "--action", "LorenzoTTGT/buzz-repo-notifier@abc123",
    "--commit",
    "--push",
  ]);

  assert.equal(options.repo, "acme/music");
  assert.equal(options.relayUrl, "https://buzz.example.com");
  assert.equal(options.channelName, "buzz-repo-notifier");
  assert.equal(options.action, "LorenzoTTGT/buzz-repo-notifier@abc123");
  assert.equal(options.commit, true);
  assert.equal(options.push, true);
});

test("builds the Buzz notification workflow", () => {
  const workflow = buildWorkflow("LorenzoTTGT/buzz-repo-notifier@abc123");

  assert.match(workflow, /issues:\n    types: \[opened\]/);
  assert.match(workflow, /push:\n    branches: \[main\]/);
  assert.match(workflow, /pull_request:\n    types: \[opened\]/);
  assert.match(workflow, /uses: LorenzoTTGT\/buzz-repo-notifier@abc123/);
  assert.match(workflow, /relay_url: \$\{\{ vars\.BUZZ_RELAY_URL \}\}/);
  assert.match(workflow, /channel_id: \$\{\{ vars\.BUZZ_CHANNEL_ID \}\}/);
  assert.match(workflow, /channel_name: \$\{\{ vars\.BUZZ_CHANNEL_NAME \}\}/);
  assert.match(workflow, /private_key: \$\{\{ secrets\.BUZZ_PRIVATE_KEY \}\}/);
});

test("installer can configure a Buzz channel name without resolving an id", async () => {
  const targetDir = await mkdtemp(join(tmpdir(), "buzz-install-"));
  const calls = [];
  const previousPrivateKey = process.env.BUZZ_PRIVATE_KEY;
  process.env.BUZZ_PRIVATE_KEY = "1".repeat(64);

  try {
    const result = await install({
      ...parseArgs([
        "--repo", "acme/music",
        "--relay-url", "https://buzz.example.com",
        "--channel-name", "buzz-repo-notifier",
        "--target-dir", targetDir,
      ]),
    }, (command, args, options = {}) => {
      calls.push({ command, args, input: options.input });
    });

    assert.equal(result.channelId, undefined);
    assert.deepEqual(calls.map((call) => call.args.slice(0, 3)), [
      ["variable", "set", "BUZZ_RELAY_URL"],
      ["variable", "set", "BUZZ_CHANNEL_NAME"],
      ["secret", "set", "BUZZ_PRIVATE_KEY"],
    ]);
  } finally {
    if (previousPrivateKey === undefined) delete process.env.BUZZ_PRIVATE_KEY;
    else process.env.BUZZ_PRIVATE_KEY = previousPrivateKey;
    await rm(targetDir, { recursive: true, force: true });
  }
});

test("installer can write only the workflow", async () => {
  const targetDir = await mkdtemp(join(tmpdir(), "buzz-install-"));
  const calls = [];

  try {
    await install({
      ...parseArgs([
        "--target-dir", targetDir,
        "--action", "LorenzoTTGT/buzz-repo-notifier@abc123",
        "--no-gh-config",
      ]),
    }, (command, args, options = {}) => {
      calls.push({ command, args, input: options.input });
    });

    const workflow = await readFile(join(targetDir, ".github/workflows/notify-buzz.yml"), "utf8");
    assert.match(workflow, /uses: LorenzoTTGT\/buzz-repo-notifier@abc123/);
    assert.deepEqual(calls, []);
  } finally {
    await rm(targetDir, { recursive: true, force: true });
  }
});

test("installer writes workflow and configures gh values", async () => {
  const targetDir = await mkdtemp(join(tmpdir(), "buzz-install-"));
  const calls = [];
  const previousPrivateKey = process.env.BUZZ_PRIVATE_KEY;
  process.env.BUZZ_PRIVATE_KEY = "nsec-test";

  try {
    const result = await install({
      ...parseArgs([
        "--repo", "acme/music",
        "--relay-url", "https://buzz.example.com",
        "--channel-id", "eb511182-5154-4631-b46b-3dd326293e4b",
        "--action", "LorenzoTTGT/buzz-repo-notifier@abc123",
        "--target-dir", targetDir,
        "--commit",
        "--push",
      ]),
    }, (command, args, options = {}) => {
      calls.push({ command, args, input: options.input });
    });

    const workflow = await readFile(join(targetDir, ".github/workflows/notify-buzz.yml"), "utf8");
    assert.equal(result.workflowFile, join(targetDir, ".github/workflows/notify-buzz.yml"));
    assert.match(workflow, /uses: LorenzoTTGT\/buzz-repo-notifier@abc123/);
    assert.deepEqual(calls, [
      {
        command: "gh",
        args: ["variable", "set", "BUZZ_RELAY_URL", "--repo", "acme/music", "--body", "https://buzz.example.com"],
        input: undefined,
      },
      {
        command: "gh",
        args: ["variable", "set", "BUZZ_CHANNEL_ID", "--repo", "acme/music", "--body", "eb511182-5154-4631-b46b-3dd326293e4b"],
        input: undefined,
      },
      {
        command: "gh",
        args: ["secret", "set", "BUZZ_PRIVATE_KEY", "--repo", "acme/music"],
        input: "nsec-test",
      },
      {
        command: "git",
        args: ["-C", targetDir, "add", ".github/workflows/notify-buzz.yml"],
        input: undefined,
      },
      {
        command: "git",
        args: ["-C", targetDir, "commit", "-m", "ci: notify Buzz on repository activity"],
        input: undefined,
      },
      {
        command: "git",
        args: ["-C", targetDir, "push"],
        input: undefined,
      },
    ]);
  } finally {
    if (previousPrivateKey === undefined) delete process.env.BUZZ_PRIVATE_KEY;
    else process.env.BUZZ_PRIVATE_KEY = previousPrivateKey;
    await rm(targetDir, { recursive: true, force: true });
  }
});
