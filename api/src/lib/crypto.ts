const encoder = new TextEncoder();

function toHex(bytes: ArrayBuffer | Uint8Array): string {
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function toBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64(text: string): Uint8Array {
  const normalized = text.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(normalized + "=".repeat((4 - (normalized.length % 4)) % 4));
  return Uint8Array.from(binary, (ch) => ch.charCodeAt(0));
}

export async function sha256Hex(input: string): Promise<string> {
  return toHex(await crypto.subtle.digest("SHA-256", encoder.encode(input)));
}

export function randomBytes(length: number): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(length));
}

export function randomToken(length = 32): string {
  return toBase64Url(randomBytes(length));
}

export function randomHex(length: number): string {
  return toHex(randomBytes(length));
}

// Rejection sampling keeps every symbol equally likely (a plain modulo would bias the low ones).
export function randomFrom(alphabet: string, length: number): string {
  const limit = 256 - (256 % alphabet.length);
  let out = "";
  while (out.length < length) {
    for (const b of randomBytes(length * 2)) {
      if (b < limit && out.length < length) out += alphabet[b % alphabet.length];
    }
  }
  return out;
}

export function randomDigits(length: number): string {
  return randomFrom("0123456789", length);
}

export async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return toHex(await crypto.subtle.sign("HMAC", key, encoder.encode(message)));
}

export function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function aesKey(base64Key: string) {
  return crypto.subtle.importKey("raw", fromBase64(base64Key), "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function encryptText(base64Key: string, plaintext: string): Promise<string> {
  const iv = randomBytes(12);
  const sealed = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    await aesKey(base64Key),
    encoder.encode(plaintext),
  );
  return `${toBase64Url(iv)}.${toBase64Url(new Uint8Array(sealed))}`;
}

export async function decryptText(base64Key: string, payload: string): Promise<string> {
  const [iv, sealed] = payload.split(".");
  if (!iv || !sealed) throw new Error("malformed ciphertext");
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: fromBase64(iv) },
    await aesKey(base64Key),
    fromBase64(sealed),
  );
  return new TextDecoder().decode(plain);
}
