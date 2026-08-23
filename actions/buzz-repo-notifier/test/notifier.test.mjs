import assert from "node:assert/strict";
import test from "node:test";
import { buildMessage, decodePrivateKey, notify } from "../src/notifier.mjs";

const key = "1".repeat(64);
const channelId = "eb511182-5154-4631-b46b-3dd326293e4b";

test("formats GitHub and Forgejo issue authors", () => {
  const github = buildMessage("issues", {
    action: "opened",
    repository: { full_name: "acme/music" },
    issue: { number: 4, title: "Needle skips", html_url: "https://example/4", user: { login: "alice" } },
  });
  const forgejo = buildMessage("issues", {
    action: "opened",
    issue: { number: 5, title: "Cover missing", html_url: "https://example/5", user: { username: "bob" } },
  }, "acme/records");

  assert.match(github, /New issue in acme\/music: Needle skips/);
  assert.match(github, /Opened by alice · #4/);
  assert.match(forgejo, /New issue in acme\/records: Cover missing/);
  assert.match(forgejo, /Opened by bob · #5/);
});

test("formats push events", () => {
  const message = buildMessage("push", {
    ref: "refs/heads/main",
    compare: "https://example/compare/1...2",
    commits: [
      { id: "123456789", message: "feat: add installer", author: { username: "alice" } },
      { id: "abcdef012", message: "fix: wait for relay auth\n\nBody", author: { name: "Bob" } },
    ],
    sender: { login: "alice" },
  }, "acme/music");

  assert.match(message, /alice updated acme\/music on main with 2 changes\./);
  assert.match(message, /Details: https:\/\/example\/compare\/1\.\.\.2/);
  assert.match(message, /What changed:/);
  assert.match(message, /- Add installer \(1234567, alice\)/);
  assert.match(message, /- Wait for relay auth \(abcdef0, Bob\)/);
});

test("summarizes large push events", () => {
  const message = buildMessage("push", {
    ref: "refs/heads/main",
    commits: Array.from({ length: 7 }, (_, index) => ({
      id: `${index}`.repeat(8),
      message: `change ${index}`,
      author: { username: "alice" },
    })),
    sender: { login: "alice" },
  }, "acme/music");

  assert.match(message, /alice updated acme\/music on main with 7 changes\./);
  assert.match(message, /- Change 4/);
  assert.doesNotMatch(message, /- Change 5/);
  assert.match(message, /- …and 2 more changes/);
});

test("formats opened pull requests but skips closes and merges", () => {
  const pull = {
    number: 12,
    title: "Add catalogue",
    html_url: "https://example/12",
    user: { login: "alice" },
    merge_commit_sha: "abcdef0123456789",
  };

  assert.match(buildMessage("pull_request", { action: "opened", pull_request: pull }, "acme/music"), /New pull request in acme\/music: Add catalogue/);
  assert.match(buildMessage("pull_request_target", { action: "opened", pull_request: pull }, "acme/music"), /New pull request in acme\/music: Add catalogue/);
  assert.equal(buildMessage("pull_request", { action: "closed", pull_request: pull }, "acme/music"), null);
  assert.equal(
    buildMessage("pull_request", {
      action: "closed",
      pull_request: { ...pull, merged: true, merged_by: { username: "malthe" } },
    }, "acme/music"),
    null,
  );
});

test("signs a channel message and NIP-98 authorization", async () => {
  let request;
  const result = await notify({
    relayUrl: "https://buzz.example/",
    channelId,
    privateKey: key,
    eventName: "issues",
    repository: "acme/music",
    payload: {
      action: "opened",
      issue: { number: 1, title: "Test", html_url: "https://example/1", user: { login: "alice" } },
    },
    fetchImpl: async (url, options) => {
      request = { url, options };
      return new Response('{"accepted":true}', { status: 200 });
    },
  });

  const message = JSON.parse(request.options.body);
  const auth = JSON.parse(Buffer.from(request.options.headers.authorization.slice(6), "base64").toString());
  assert.equal(request.url, "https://buzz.example/events");
  assert.deepEqual(message.tags, [["h", channelId]]);
  assert.equal(message.kind, 9);
  assert.equal(auth.kind, 27235);
  assert.ok(auth.tags.some((tag) => tag[0] === "payload"));
  assert.equal(result.eventId, message.id);
});

test("resolves a channel by name when no channel id is configured", async () => {
  let request;
  const result = await notify({
    relayUrl: "wss://buzz.example/",
    channelName: "acme/music",
    privateKey: key,
    eventName: "issues",
    repository: "acme/music",
    payload: {
      action: "opened",
      issue: { number: 1, title: "Test", html_url: "https://example/1", user: { login: "alice" } },
    },
    fetchImpl: async (url, options) => {
      request = { url, options };
      return new Response('{"accepted":true}', { status: 200 });
    },
    channelManager: async ({ relayUrl, channelName, privateKey }) => {
      assert.equal(relayUrl, "wss://buzz.example/");
      assert.equal(channelName, "acme/music");
      assert.equal(privateKey.length, 32);
      return channelId;
    },
  });

  const message = JSON.parse(request.options.body);
  assert.equal(request.url, "https://buzz.example/events");
  assert.deepEqual(message.tags, [["h", channelId]]);
  assert.equal(result.eventId, message.id);
});

test("validates credentials and channel identifiers before sending", async () => {
  assert.equal(decodePrivateKey(key).length, 32);
  assert.throws(() => decodePrivateKey("bad"), /private_key/);
  await assert.rejects(
    notify({
      relayUrl: "https://buzz.example",
      channelId: "bad",
      privateKey: key,
      eventName: "issues",
      payload: { action: "opened", issue: {} },
    }),
    /channel_id/,
  );
});
