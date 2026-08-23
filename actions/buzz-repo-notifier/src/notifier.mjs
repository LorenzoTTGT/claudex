import { createHash, randomUUID } from "node:crypto";
import { finalizeEvent } from "nostr-tools";
import { ensureBuzzChannel } from "./channel.mjs";
import { decodePrivateKey } from "./keys.mjs";

export { decodePrivateKey };

export async function notify({
  relayUrl,
  channelId,
  channelName,
  privateKey,
  eventName,
  payload,
  repository,
  fetchImpl = fetch,
  channelManager = ensureBuzzChannel,
}) {
  const content = buildMessage(eventName, payload, repository);
  if (!content) return { skipped: true };

  const key = decodePrivateKey(privateKey);
  const resolvedChannelId = channelId
    ? validateChannelId(channelId)
    : await channelManager({
      relayUrl,
      channelName: channelName || repository,
      privateKey: key,
    });
  const endpoint = `${normalizeRelayUrl(relayUrl)}/events`;
  const event = finalizeEvent(
    {
      kind: 9,
      created_at: Math.floor(Date.now() / 1000),
      tags: [["h", validateChannelId(resolvedChannelId)]],
      content,
    },
    key,
  );
  const body = JSON.stringify(event);
  const response = await fetchImpl(endpoint, {
    method: "POST",
    headers: {
      authorization: signHttpRequest(endpoint, body, key),
      "content-type": "application/json",
    },
    body,
  });
  const responseBody = await response.text();

  if (!response.ok) {
    throw new Error(`Buzz rejected the notification (${response.status}): ${responseBody}`);
  }

  return { skipped: false, eventId: event.id, content };
}

export function buildMessage(eventName, event, fallbackRepository) {
  const action = event.action;
  const repository = event.repository?.full_name ?? fallbackRepository ?? "repository";

  if (eventName === "issues" && action === "opened" && event.issue) {
    const issue = event.issue;
    return [
      `New issue in ${repository}: ${issue.title}`,
      `Opened by ${displayName(issue.user)} · #${issue.number} · ${issue.html_url}`,
    ].join("\n");
  }

  if (eventName === "push") {
    const branch = event.ref?.replace(/^refs\/heads\//, "") ?? "unknown branch";
    const commits = event.commits ?? [];
    const changeLabel = commits.length === 1 ? "1 change" : `${commits.length} changes`;
    const commitLines = commits.slice(0, 5).map((commit) => {
      const subject = humanizeCommitSubject(firstLine(commit.message) || "Untitled commit");
      return `- ${subject} (${shortSha(commit.id)}, ${commitAuthor(commit)})`;
    });
    const remaining = commits.length - commitLines.length;
    if (remaining > 0) commitLines.push(`- …and ${remaining} more changes`);

    return [
      `${displayName(event.sender ?? event.pusher)} updated ${repository} on ${branch} with ${changeLabel}.`,
      event.compare ? `Details: ${event.compare}` : null,
      commitLines.length ? "What changed:" : null,
      ...commitLines,
    ].filter(Boolean).join("\n");
  }

  if ((eventName === "pull_request" || eventName === "pull_request_target") && action === "opened" && event.pull_request) {
    const pull = event.pull_request;
    return [
      `New pull request in ${repository}: ${pull.title}`,
      `Opened by ${displayName(pull.user)} · #${pull.number} · ${pull.html_url}`,
    ].join("\n");
  }

  return null;
}

function signHttpRequest(url, body, key) {
  const authEvent = finalizeEvent(
    {
      kind: 27235,
      created_at: Math.floor(Date.now() / 1000),
      tags: [
        ["u", url],
        ["method", "POST"],
        ["nonce", randomUUID()],
        ["payload", createHash("sha256").update(body).digest("hex")],
      ],
      content: "",
    },
    key,
  );
  return `Nostr ${Buffer.from(JSON.stringify(authEvent)).toString("base64")}`;
}

function normalizeRelayUrl(value) {
  const url = new URL(value);
  if (url.protocol === "ws:") url.protocol = "http:";
  else if (url.protocol === "wss:") url.protocol = "https:";
  else if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error("relay_url must use http, https, ws, or wss");
  }
  return url.toString().replace(/\/$/, "");
}

function validateChannelId(value) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new Error("channel_id must be a UUID");
  }
  return value;
}

function humanizeCommitSubject(value) {
  const withoutConventionalPrefix = value.replace(/^[a-z]+(?:\([^)]+\))?!?:\s+/i, "");
  return withoutConventionalPrefix.charAt(0).toUpperCase() + withoutConventionalPrefix.slice(1);
}

function firstLine(value) {
  return value?.split("\n", 1)[0]?.trim() ?? "";
}

function shortSha(value) {
  return value?.slice(0, 7) ?? "unknown";
}

function commitAuthor(commit) {
  return commit.author?.username ?? commit.author?.name ?? "unknown";
}

function displayName(user) {
  return user?.login ?? user?.username ?? user?.name ?? "unknown";
}
