const HETZNER_API_BASE = "https://api.hetzner.cloud/v1";

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function sendTelegram(env, text) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) {
    return;
  }
  const endpoint = `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`;
  await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      chat_id: env.TELEGRAM_CHAT_ID,
      text,
      disable_web_page_preview: true,
    }),
  });
}

async function hetznerRequest(env, path, method = "GET", body = null) {
  const res = await fetch(`${HETZNER_API_BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${env.HETZNER_API_TOKEN}`,
      "content-type": "application/json",
    },
    body: body ? JSON.stringify(body) : null,
  });

  const text = await res.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    payload = { raw: text };
  }

  if (!res.ok) {
    throw new Error(`Hetzner ${method} ${path} failed: ${res.status} ${text}`);
  }

  return payload;
}

async function fetchCloudInitFromR2(env) {
  const object = await env.BOOTSTRAP_BUCKET.get("cloud-init/user-data.sh");
  if (!object) {
    throw new Error("cloud-init/user-data.sh not found in R2");
  }
  return await object.text();
}

async function attachPrimaryIps(env, serverId, activeIpIds) {
  for (const ipId of activeIpIds) {
    const id = Number(ipId.trim());
    if (!Number.isInteger(id)) {
      continue;
    }
    await hetznerRequest(env, `/primary_ips/${id}/actions/assign`, "POST", {
      assignee_id: serverId,
      assignee_type: "server",
      auto_delete: false,
    });
  }
}

async function resolvePrimaryIpIds(env) {
  const configured = (env.ACTIVE_IPS || "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
  if (!configured.length) {
    return [];
  }

  const ids = [];
  const ipsToResolve = [];

  for (const token of configured) {
    if (/^\d+$/.test(token)) {
      ids.push(Number(token));
    } else {
      ipsToResolve.push(token);
    }
  }

  if (!ipsToResolve.length) {
    return ids;
  }

  const listResponse = await hetznerRequest(env, "/primary_ips?per_page=200");
  const lookup = new Map(
    (listResponse.primary_ips || []).map((ip) => [ip.ip, ip.id])
  );
  for (const ip of ipsToResolve) {
    if (lookup.has(ip)) {
      ids.push(Number(lookup.get(ip)));
    }
  }
  return ids;
}

async function spawn(env) {
  const cloudInit = await fetchCloudInitFromR2(env);
  const requestBody = {
    name: `namma-ephemeral-${Date.now()}`,
    server_type: env.HETZNER_SERVER_TYPE || "cx33",
    location: env.HETZNER_LOCATION || "hel1",
    image: env.HETZNER_IMAGE || "ubuntu-24.04",
    ssh_keys: env.HETZNER_SSH_KEY_IDS
      ? env.HETZNER_SSH_KEY_IDS.split(",").map((v) => Number(v.trim())).filter(Boolean)
      : undefined,
    firewall_ids: env.HETZNER_FIREWALL_ID
      ? [Number(env.HETZNER_FIREWALL_ID)]
      : undefined,
    networks: env.HETZNER_NETWORK_ID
      ? [{ network: Number(env.HETZNER_NETWORK_ID) }]
      : undefined,
    user_data: cloudInit,
  };

  const created = await hetznerRequest(env, "/servers", "POST", requestBody);
  const serverId = created.server.id;

  const activeIpIds = await resolvePrimaryIpIds(env);
  if (activeIpIds.length) {
    await attachPrimaryIps(env, serverId, activeIpIds);
  }

  await sendTelegram(
    env,
    `✅ CX33 spawned: id=${serverId}, name=${created.server.name}, ip=${created.server.public_net.ipv4?.ip || "pending"}`
  );

  return created;
}

export default {
  async scheduled(_event, env, _ctx) {
    try {
      await spawn(env);
    } catch (err) {
      await sendTelegram(env, `❌ Spawn failed: ${err.message}`);
      throw err;
    }
  },

  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return jsonResponse({ ok: true, service: "spawn-server-worker" });
    }

    if (request.method !== "POST") {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const auth = request.headers.get("authorization");
    if (env.SPAWN_WORKER_TOKEN && auth !== `Bearer ${env.SPAWN_WORKER_TOKEN}`) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }

    try {
      const data = await spawn(env);
      return jsonResponse({ ok: true, data });
    } catch (err) {
      await sendTelegram(env, `❌ Manual spawn failed: ${err.message}`);
      return jsonResponse({ ok: false, error: err.message }, 500);
    }
  },
};
