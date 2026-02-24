CREATE TABLE IF NOT EXISTS articles (
    id SERIAL PRIMARY KEY,
    source_url TEXT UNIQUE NOT NULL,
    publisher_name VARCHAR(100) NOT NULL,
    cdn_image_url TEXT,
    raw_title TEXT NOT NULL,
    ai_summary TEXT NOT NULL,
    ai_title TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    location VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT articles_location_check CHECK (location IN (
        'chennai', 'coimbatore', 'madurai', 'trichy', 'virudhunagar'
    ))
);

CREATE INDEX IF NOT EXISTS idx_articles_location_date ON articles(location, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_created_at ON articles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_category ON articles(category);
CREATE INDEX IF NOT EXISTS idx_articles_source_url ON articles USING hash(source_url);

CREATE TABLE IF NOT EXISTS ads (
    id SERIAL PRIMARY KEY,
    advertiser_name VARCHAR(100) NOT NULL,
    advertiser_email VARCHAR(255),
    advertiser_phone VARCHAR(20),
    district VARCHAR(50) NOT NULL,
    position VARCHAR(20) NOT NULL,
    html_content TEXT NOT NULL,
    tracking_url TEXT NOT NULL,
    image_url TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 1,
    price_paid NUMERIC(10,2),
    currency VARCHAR(3) DEFAULT 'INR',
    impressions_total INTEGER DEFAULT 0,
    clicks_total INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ads_district_check CHECK (
        district IN ('all', 'chennai', 'coimbatore', 'madurai', 'trichy', 'virudhunagar')
    ),
    CONSTRAINT ads_position_check CHECK (
        position IN ('header', 'mid', 'footer', 'inline')
    )
);

CREATE INDEX IF NOT EXISTS idx_ads_district_active ON ads(district, is_active, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_ads_position ON ads(position);
CREATE INDEX IF NOT EXISTS idx_ads_priority ON ads(priority DESC);

CREATE TABLE IF NOT EXISTS ad_performance (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER REFERENCES ads(id) ON DELETE CASCADE,
    campaign_id INTEGER,
    district VARCHAR(50) NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    unique_clicks INTEGER DEFAULT 0,
    ctr NUMERIC(5,2) GENERATED ALWAYS AS (
        CASE WHEN impressions > 0
        THEN ROUND((clicks::NUMERIC / impressions * 100), 2)
        ELSE 0 END
    ) STORED,
    revenue_earned NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ad_performance_unique UNIQUE (ad_id, date, district)
);

CREATE INDEX IF NOT EXISTS idx_ad_performance_date ON ad_performance(date DESC);
CREATE INDEX IF NOT EXISTS idx_ad_performance_ad_id ON ad_performance(ad_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_ad_performance_district ON ad_performance(district, date DESC);

CREATE TABLE IF NOT EXISTS campaign_metrics (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL,
    district VARCHAR(50) NOT NULL,
    sending_ip INET NOT NULL,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    bounced_count INTEGER DEFAULT 0,
    opened_count INTEGER DEFAULT 0,
    clicked_count INTEGER DEFAULT 0,
    spam_complaint_count INTEGER DEFAULT 0,
    send_started_at TIMESTAMPTZ,
    send_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_campaign_metrics_district ON campaign_metrics(district, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_campaign_metrics_campaign_id ON campaign_metrics(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_metrics_date ON campaign_metrics(created_at DESC);

CREATE TABLE IF NOT EXISTS ip_scaling_history (
    id SERIAL PRIMARY KEY,
    ip_address INET NOT NULL,
    ip_id INTEGER NOT NULL,
    trigger_reason VARCHAR(255) NOT NULL,
    daily_sends_at_trigger INTEGER NOT NULL,
    ips_before INTEGER NOT NULL,
    ips_after INTEGER NOT NULL,
    monthly_cost_before NUMERIC(10,2),
    monthly_cost_after NUMERIC(10,2),
    ptr_record VARCHAR(255),
    spf_record_updated TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ip_scaling_date ON ip_scaling_history(created_at DESC);

CREATE TABLE IF NOT EXISTS warmup_state (
    id SERIAL PRIMARY KEY,
    current_phase INTEGER NOT NULL DEFAULT 1,
    phase_started_at DATE NOT NULL DEFAULT CURRENT_DATE,
    max_sends_today INTEGER NOT NULL DEFAULT 150,
    open_rate NUMERIC(5,2) DEFAULT 0,
    bounce_rate NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_warmup_singleton ON warmup_state((id = 1));
