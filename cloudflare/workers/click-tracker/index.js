export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/l\/([^/]+)$/);
    if (!match) {
      return new Response("Invalid link format", { status: 404 });
    }

    const token = match[1];

    const link = await env.DB.prepare(
      `SELECT destination_url, campaign_id, ad_id, district
       FROM click_links
       WHERE token = ?`
    )
      .bind(token)
      .first();

    if (!link) {
      return new Response("Link expired or invalid", { status: 410 });
    }

    const subscriberId = url.searchParams.get("sid");
    const userAgent = request.headers.get("user-agent") || "";
    const ipAddress = request.headers.get("cf-connecting-ip") || "";

    ctx.waitUntil(
      env.DB.prepare(
        `INSERT INTO click_events
         (token, subscriber_id, clicked_at, user_agent, ip_address, is_synced)
         VALUES (?, ?, ?, ?, ?, 0)`
      )
        .bind(
          token,
          subscriberId,
          new Date().toISOString(),
          userAgent,
          ipAddress
        )
        .run()
        .catch((err) => {
          console.error("Failed to record click event", err);
        })
    );

    return Response.redirect(link.destination_url, 302);
  },
};
