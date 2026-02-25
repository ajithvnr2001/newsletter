const VALID_DISTRICTS = new Set([
  "chennai",
  "coimbatore",
  "madurai",
  "trichy",
  "virudhunagar",
]);

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "POST, OPTIONS",
      "access-control-allow-headers": "content-type",
    },
  });
}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizeDistrict(value) {
  return String(value || "").trim().toLowerCase();
}

function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return json({ ok: true }, 200);
    }

    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Invalid JSON payload" }, 400);
    }

    const email = normalizeEmail(payload.email);
    const district = normalizeDistrict(payload.district);
    const nameFromEmail = email.includes("@") ? email.split("@")[0] : "Reader";
    const name = String(payload.name || "").trim() || nameFromEmail;

    if (!validateEmail(email)) {
      return json({ error: "Invalid email format" }, 400);
    }

    if (!VALID_DISTRICTS.has(district)) {
      return json({ error: "Invalid district" }, 400);
    }

    const existing = await env.DB.prepare(
      `SELECT id
       FROM pending_subscribers
       WHERE email = ? AND district = ?`
    )
      .bind(email, district)
      .first();

    if (existing) {
      return json(
        { message: "You are already subscribed to this district newsletter!" },
        200
      );
    }

    try {
      await env.DB.prepare(
        `INSERT INTO pending_subscribers (email, district, name, signed_up_at, is_synced)
         VALUES (?, ?, ?, ?, 0)`
      )
        .bind(email, district, name, new Date().toISOString())
        .run();
    } catch (error) {
      const message = String(error?.message || error || "");
      if (message.includes("UNIQUE constraint failed")) {
        return json(
          { message: "You are already subscribed to this district newsletter!" },
          200
        );
      }
      console.error("Subscription insert failed", error);
      return json({ error: "Unable to process subscription right now" }, 500);
    }

    return json({
      success: true,
      message: `Welcome to Namma Ooru News - ${district}! Your first newsletter arrives tomorrow at 6:30 AM.`,
    });
  },
};
