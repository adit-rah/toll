import { PhotonImage, resize, SamplingFilter } from "@cf-wasm/photon";
import { eq } from "drizzle-orm";
import { defaultConfig, serverConfig } from "../../config";
import { users } from "../../db/schema";
import type { Env } from "../../env";
import { randomHex } from "../../lib/crypto";
import type { Database } from "../../lib/db";
import { fail } from "../../lib/http";

export const PHOTO_KEY = /^[0-9a-f]{32}\.jpg$/;
const r2Path = (key: string) => `photos/${key}`;

// Re-encoding also strips EXIF (location, device) from whatever the phone sent.
export function toStoredJpeg(bytes: Uint8Array, maxPx: number): Uint8Array {
  const image = PhotonImage.new_from_byteslice(bytes);
  try {
    const width = image.get_width();
    const height = image.get_height();
    const scale = Math.min(1, maxPx / Math.max(width, height));
    if (scale === 1) return image.get_bytes_jpeg(85);
    const resized = resize(
      image,
      Math.max(1, Math.round(width * scale)),
      Math.max(1, Math.round(height * scale)),
      SamplingFilter.Lanczos3,
    );
    try {
      return resized.get_bytes_jpeg(85);
    } finally {
      resized.free();
    }
  } finally {
    image.free();
  }
}

export async function replacePhoto(
  db: Database,
  env: Env,
  userId: string,
  contentType: string,
  body: ArrayBuffer,
): Promise<void> {
  if (!["image/jpeg", "image/png"].includes(contentType)) fail(415, "photo_invalid");
  if (body.byteLength === 0) fail(400, "photo_invalid");
  if (body.byteLength > serverConfig.photoMaxUploadBytes) fail(413, "photo_too_large");
  let jpeg: Uint8Array;
  try {
    jpeg = toStoredJpeg(new Uint8Array(body), defaultConfig.identity.photoMaxPx);
  } catch {
    fail(400, "photo_invalid");
  }
  const key = `${randomHex(16)}.jpg`;
  await env.STORAGE.put(r2Path(key), jpeg, { httpMetadata: { contentType: "image/jpeg" } });
  await swapPhotoKey(db, env, userId, key);
}

export async function swapPhotoKey(db: Database, env: Env, userId: string, key: string | null) {
  const [user] = await db.select({ photoKey: users.photoKey }).from(users).where(eq(users.id, userId));
  await db.update(users).set({ photoKey: key }).where(eq(users.id, userId));
  if (user?.photoKey) await env.STORAGE.delete(r2Path(user.photoKey));
}

export async function servePhoto(env: Env, key: string): Promise<Response | null> {
  if (!PHOTO_KEY.test(key)) return null;
  const object = await env.STORAGE.get(r2Path(key));
  if (!object) return null;
  return new Response(object.body, {
    headers: {
      "content-type": "image/jpeg",
      // Keys are random and replaced on every change, so a cached photo is never stale.
      "cache-control": `public, max-age=${serverConfig.photoCacheSeconds}, immutable`,
    },
  });
}
