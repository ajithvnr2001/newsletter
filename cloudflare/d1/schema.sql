-- Permanent 24/7 click tracking storage in Cloudflare D1.

CREATE TABLE IF NOT EXISTS click_links (
  token TEXT PRIMARY KEY,
  campaign_id INTEGER NOT NULL,
  ad_id INTEGER,
  district TEXT NOT NULL CHECK (
    district IN ('chennai', 'coimbatore', 'madurai', 'trichy', 'virudhunagar', 'all')
  ),
  destination_url TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_click_links_token ON click_links(token);
CREATE INDEX IF NOT EXISTS idx_click_links_campaign ON click_links(campaign_id);
CREATE INDEX IF NOT EXISTS idx_click_links_created_at ON click_links(created_at);

CREATE TABLE IF NOT EXISTS click_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token TEXT NOT NULL,
  subscriber_id TEXT,
  clicked_at TEXT NOT NULL,
  user_agent TEXT,
  ip_address TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0 CHECK (is_synced IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_click_events_token ON click_events(token);
CREATE INDEX IF NOT EXISTS idx_click_events_synced ON click_events(is_synced, clicked_at);
CREATE INDEX IF NOT EXISTS idx_click_events_clicked_at ON click_events(clicked_at);
