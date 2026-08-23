import { nip19 } from "nostr-tools";

export function decodePrivateKey(value) {
  if (/^[0-9a-f]{64}$/i.test(value)) {
    return Uint8Array.from(Buffer.from(value, "hex"));
  }
  if (value.startsWith("nsec1")) {
    const decoded = nip19.decode(value);
    if (decoded.type === "nsec") return decoded.data;
  }
  throw new Error("private_key must be a 64-character hex key or nsec");
}
