# DNS Setup (Cloudflare + Hetzner)

⚠️ WARNING: Do not send production mail until PTR for `95.217.13.142` is set to `mail.nammaoorunews.com` in Hetzner and verified with `dig -x`.

## SPF
Day 1:
- `@ TXT "v=spf1 ip4:95.217.13.142 ~all"`

Auto-scaled example:
- `@ TXT "v=spf1 ip4:95.217.13.142 ip4:95.217.13.200 ip4:95.217.13.201 ~all"`

## DKIM
- `mail._domainkey TXT "v=DKIM1; k=rsa; p=<mail_public_key>"`
- `mail2._domainkey TXT "v=DKIM1; k=rsa; p=<mail2_public_key>"`
- `mail3._domainkey TXT "v=DKIM1; k=rsa; p=<mail3_public_key>"`

## DMARC
Week 1-2:
- `_dmarc TXT "v=DMARC1; p=none; rua=mailto:dmarc@nammaoorunews.com; pct=100; adkim=r; aspf=r"`

Week 3-4:
- `_dmarc TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@nammaoorunews.com; pct=100; adkim=s; aspf=s"`

Week 5+:
- `_dmarc TXT "v=DMARC1; p=reject; rua=mailto:dmarc@nammaoorunews.com; pct=100; adkim=s; aspf=s"`

## MX
- `@ MX 10 mail.nammaoorunews.com`

## PTR (Hetzner Console)
1. Hetzner Cloud -> Primary IPs.
2. Click three-dot menu for the IP.
3. Edit reverse DNS.
4. Set `95.217.13.142 -> mail.nammaoorunews.com`.
5. Verify: `dig -x 95.217.13.142 +short`.
