INSERT INTO warmup_state (id, current_phase, phase_started_at, max_sends_today)
VALUES (1, 1, CURRENT_DATE, 150)
ON CONFLICT (id) DO NOTHING;

-- District lists are expected in listmonk tables. This seed keeps a local reference.
CREATE TABLE IF NOT EXISTS district_lists (
    id SERIAL PRIMARY KEY,
    district VARCHAR(50) UNIQUE NOT NULL,
    list_name VARCHAR(100) NOT NULL,
    listmonk_list_id INTEGER
);

INSERT INTO district_lists (district, list_name, listmonk_list_id)
VALUES
  ('chennai', 'Chennai Daily', 1),
  ('coimbatore', 'Coimbatore Daily', 2),
  ('madurai', 'Madurai Daily', 3),
  ('trichy', 'Trichy Daily', 4),
  ('virudhunagar', 'Virudhunagar Daily', 5)
ON CONFLICT (district) DO NOTHING;

DO $$
BEGIN
  IF to_regclass('public.lists') IS NOT NULL THEN
    BEGIN
      INSERT INTO public.lists (name, type, optin)
      VALUES
        ('Chennai Daily', 'public', 'double'),
        ('Coimbatore Daily', 'public', 'double'),
        ('Madurai Daily', 'public', 'double'),
        ('Trichy Daily', 'public', 'double'),
        ('Virudhunagar Daily', 'public', 'double')
      ON CONFLICT DO NOTHING;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Skipping direct Listmonk lists seed due to schema mismatch: %', SQLERRM;
    END;
  END IF;
END $$;

INSERT INTO ads (
    advertiser_name,
    advertiser_email,
    advertiser_phone,
    district,
    position,
    html_content,
    tracking_url,
    image_url,
    start_date,
    end_date,
    is_active,
    priority,
    price_paid,
    currency
)
VALUES
(
    'VND Silk Sarees',
    'hello@vndsilksarees.com',
    '+91-90000-11111',
    'virudhunagar',
    'mid',
    '<table width="100%" style="background:#fff7ed;border:2px solid #f97316;border-radius:8px;padding:16px;margin:20px 0;"><tr><td><p style="font-size:11px;color:#f97316;margin:0;text-transform:uppercase;">விளம்பரம் (Sponsored)</p><p style="font-size:16px;font-weight:bold;color:#1a1a1a;margin:8px 0;">விருதுநகர் சிறந்த பட்டு புடவைகள்</p><p style="font-size:14px;color:#444;">VND Silk Sarees - தீபாவளி சிறப்பு 40% தள்ளுபடி</p><a href="https://click.quoteviral.online/l/vnd-silk-123" style="background:#f97316;color:#fff;padding:8px 16px;border-radius:4px;text-decoration:none;font-size:14px;">இப்போதே பார்வையிடுங்கள் →</a></td></tr></table>',
    'https://vndsilksarees.com/diwali-sale',
    'https://cdn.quoteviral.online/ads/vnd-silk-mid.jpg',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    TRUE,
    10,
    5000.00,
    'INR'
),
(
    'Namma Ooru Default Sponsor',
    'ads@quoteviral.online',
    '+91-90000-22222',
    'all',
    'footer',
    '<table width="100%" style="background:#f8fafc;border:1px solid #cbd5e1;border-radius:8px;padding:16px;margin:20px 0;"><tr><td><p style="font-size:11px;color:#475569;margin:0;text-transform:uppercase;">Sponsored</p><p style="font-size:15px;font-weight:bold;color:#0f172a;margin:8px 0;">Advertise with Namma Ooru News</p><a href="https://quoteviral.online/advertise" style="background:#0f172a;color:#fff;padding:8px 16px;border-radius:4px;text-decoration:none;font-size:14px;">Book Slot</a></td></tr></table>',
    'https://quoteviral.online/advertise',
    'https://cdn.quoteviral.online/ads/default-footer.jpg',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '365 days',
    TRUE,
    1,
    0,
    'INR'
)
ON CONFLICT DO NOTHING;
