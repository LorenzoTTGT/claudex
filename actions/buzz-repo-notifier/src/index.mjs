import { readFile } from "node:fs/promises";
import { notify } from "./notifier.mjs";

const eventPath = requireEnv("GITHUB_EVENT_PATH");
const eventName = requireEnv("GITHUB_EVENT_NAME");
const payload = JSON.parse(await readFile(eventPath, "utf8"));

const repository = process.env.GITHUB_REPOSITORY;
const result = await notify({
  relayUrl: requireInput("RELAY_URL"),
  channelId: optionalInput("CHANNEL_ID"),
  channelName: optionalInput("CHANNEL_NAME") || repository,
  privateKey: requireInput("PRIVATE_KEY"),
  eventName,
  payload,
  repository,
});

if (result.skipped) {
  console.log(`No Buzz notification needed for ${eventName}:${payload.action ?? "unknown"}`);
} else {
  console.log(`Buzz notification accepted for ${eventName}:${payload.action}`);
}

function requireInput(name) {
  return requireEnv(`INPUT_${name}`);
}

function optionalInput(name) {
  return process.env[`INPUT_${name}`] || undefined;
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}
