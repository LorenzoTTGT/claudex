import { finalizeEvent, Relay } from "nostr-tools";
import { decodePrivateKey } from "./keys.mjs";

export async function ensureBuzzChannel({ relayUrl, channelName, privateKey }) {
  if (!channelName) throw new Error("channel_name is required when channel_id is not set");
  const key = typeof privateKey === "string" ? decodePrivateKey(privateKey) : privateKey;
  const relay = await Relay.connect(toWebSocketRelayUrl(relayUrl));

  try {
    await authenticateRelay(relay, key);
    const existing = await findChannelByName(relay, channelName);
    if (existing) return existing;

    const createEvent = finalizeEvent({
      kind: 9007,
      created_at: Math.floor(Date.now() / 1000),
      tags: [["name", channelName], ["visibility", "open"]],
      content: "",
    }, key);
    await relay.publish(createEvent);

    for (let attempt = 0; attempt < 5; attempt += 1) {
      const created = await findChannelByName(relay, channelName);
      if (created) return created;
      await new Promise((resolveDelay) => setTimeout(resolveDelay, 500));
    }

    throw new Error(`Created Buzz channel ${channelName}, but could not discover its UUID`);
  } finally {
    relay.close();
  }
}

async function authenticateRelay(relay, key) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    try {
      await relay.auth((event) => Promise.resolve(finalizeEvent(event, key)));
      return;
    } catch (error) {
      if (!/no challenge/i.test(error.message)) throw error;
      await new Promise((resolveDelay) => setTimeout(resolveDelay, 250));
    }
  }
}

async function findChannelByName(relay, channelName) {
  const events = [];
  await new Promise((resolveQuery) => {
    const timeout = setTimeout(() => {
      subscription.close("channel lookup timed out");
      resolveQuery();
    }, 8000);
    const subscription = relay.subscribe([{ kinds: [39000] }], {
      onevent: (event) => events.push(event),
      oneose: () => {
        clearTimeout(timeout);
        subscription.close();
        resolveQuery();
      },
      onclose: () => {
        clearTimeout(timeout);
        resolveQuery();
      },
    });
  });

  for (const event of events) {
    const name = event.tags.find((tag) => tag[0] === "name")?.[1];
    const channelId = event.tags.find((tag) => tag[0] === "d")?.[1];
    if (name === channelName && channelId) return channelId;
  }
  return null;
}

function toWebSocketRelayUrl(value) {
  const url = new URL(value);
  if (url.protocol === "http:") url.protocol = "ws:";
  else if (url.protocol === "https:") url.protocol = "wss:";
  else if (!["ws:", "wss:"].includes(url.protocol)) throw new Error("relay_url must use http, https, ws, or wss");
  return url.toString();
}
