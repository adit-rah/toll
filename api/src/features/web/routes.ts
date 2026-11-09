import { Hono } from "hono";
import { serverConfig } from "../../config";
import { copy } from "../../copy";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { inviteName } from "../friends/routes";
import { userByInviteCode } from "../friends/service";

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);

function page(text: { title: string; line: string; button: string }, storeUrl: string): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(text.title)}</title>
<style>
:root{color-scheme:light dark;--bg:#fff;--fg:#111;--muted:#555;--accent:#111}
@media (prefers-color-scheme:dark){:root{--bg:#000;--fg:#f2f2f2;--muted:#a0a0a0;--accent:#f2f2f2}}
body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.45 -apple-system,system-ui,sans-serif}
main{max-width:28rem;margin:0 auto;padding:22vh 1.5rem 3rem;text-align:center}
h1{font-size:1.6rem;margin:0 0 .75rem}p{color:var(--muted);margin:0 0 2rem}
a{display:inline-block;padding:.8rem 1.4rem;border-radius:999px;background:var(--accent);color:var(--bg);text-decoration:none;font-weight:600}
</style></head>
<body><main><h1>${escapeHtml(text.title)}</h1><p>${escapeHtml(text.line)}</p>
<a href="${escapeHtml(storeUrl)}">${escapeHtml(text.button)}</a></main></body></html>`;
}

// Universal links open the app directly when it is installed; this page is only seen without it.
export const webRoutes = new Hono<AppEnv>()
  .get("/i/:code", async (c) => {
    const storeUrl = c.env.APP_STORE_URL || serverConfig.appStoreUrl;
    const user = await userByInviteCode(database(c.env.DB), c.req.param("code"));
    if (!user) return c.html(page(copy.inviteMissing, storeUrl), 404);
    return c.html(page(copy.invitePage(inviteName(user)), storeUrl));
  })
  .get("/.well-known/apple-app-site-association", (c) =>
    c.json({
      applinks: {
        details: [
          {
            appIDs: [`${c.env.APPLE_TEAM_ID}.${c.env.APPLE_BUNDLE_ID}`],
            components: [{ "/": "/i/*" }],
          },
        ],
      },
    }),
  );
