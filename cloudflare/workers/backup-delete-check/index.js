const HETZNER_API_BASE = "https://api.hetzner.cloud/v1";

async function telegram(env, text) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) return;
  await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id: env.TELEGRAM_CHAT_ID, text }),
  });
}

async function hetzner(env, path, method = "GET") {
  const res = await fetch(`${HETZNER_API_BASE}${path}`, {
    method,
    headers: { Authorization: `Bearer ${env.HETZNER_API_TOKEN}` },
  });
  if (!res.ok) {
    const msg = await res.text();
    throw new Error(`Hetzner ${method} ${path} failed: ${res.status} ${msg}`);
  }
  return res.status === 204 ? null : res.json();
}

async function forceDeleteIfNeeded(env) {
  const targetNamePrefix = env.SERVER_NAME_PREFIX || "namma-ephemeral-";
  const data = await hetzner(env, "/servers");
  const active = (data.servers || []).filter((s) =>
    String(s.name || "").startsWith(targetNamePrefix)
  );

  for (const server of active) {
    await hetzner(env, `/servers/${server.id}`, "DELETE");
    await telegram(env, `⚠️ Backup delete forced for server ${server.id} (${server.name})`);
  }

  if (active.length === 0) {
    await telegram(env, "✅ Backup delete check passed: no ephemeral server running");
  }

  return active.length;
}

export default {
  async scheduled(_event, env) {
    await forceDeleteIfNeeded(env);
  },
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    const auth = request.headers.get("authorization");
    const deleteToken = env.DELETE_WORKER_TOKEN || env.SELF_DELETE_WORKER_TOKEN || "";
    if (deleteToken && auth !== `Bearer ${deleteToken}`) {
      return new Response("Unauthorized", { status: 401 });
    }
    const count = await forceDeleteIfNeeded(env);
    return Response.json({ ok: true, deleted_servers: count });
  },
};
