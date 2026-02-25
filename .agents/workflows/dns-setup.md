---
description: Set up all DNS records for email deliverability (SPF, DKIM, DMARC, PTR)
---

# DNS Setup

Configure all DNS records required for email authentication and deliverability.

## Prerequisites
- Cloudflare account with zone `nammaoorunews.com`
- Hetzner Cloud access for PTR record
- DKIM keys generated (see Step 1)

## Steps

1. Generate DKIM keys:
```bash
mkdir -p /etc/opendkim/keys
opendkim-genkey -b 2048 -d nammaoorunews.com -s mail -D /etc/opendkim/keys/
# Repeat for mail1-mail10:
for i in $(seq 1 10); do
  opendkim-genkey -b 2048 -d nammaoorunews.com -s "mail${i}" -D /etc/opendkim/keys/
done
```

2. Set Hetzner PTR record:
   - Go to Hetzner Cloud → Primary IPs → `95.217.13.142` → Edit Reverse DNS
   - Set PTR: `mail.nammaoorunews.com`

// turbo
3. Verify PTR:
```bash
dig -x 95.217.13.142 +short
```
Expected: `mail.nammaoorunews.com.`

4. Add Cloudflare DNS records (via dashboard or API):

   **SPF** (Day 1):
   - Type: TXT, Name: `@`
   - Value: `v=spf1 ip4:95.217.13.142 ~all`

   **DKIM** (primary):
   - Type: TXT, Name: `mail._domainkey`
   - Value: contents of `/etc/opendkim/keys/mail.txt`

   **DMARC** (Week 1-2, relaxed):
   - Type: TXT, Name: `_dmarc`
   - Value: `v=DMARC1; p=none; rua=mailto:dmarc@nammaoorunews.com; pct=100; adkim=r; aspf=r`

   **MX**:
   - Type: MX, Name: `@`, Priority: 10
   - Value: `mail.nammaoorunews.com`

5. Check IP blacklist status:
   - Visit https://mxtoolbox.com/blacklists.aspx
   - Enter: `95.217.13.142`
   - If listed on Spamhaus: https://check.spamhaus.org/
   - If listed on Microsoft: https://sender.office.com/

6. After warmup Week 3-4, tighten DMARC:
   - Update to: `v=DMARC1; p=quarantine; rua=mailto:dmarc@nammaoorunews.com; pct=100; adkim=s; aspf=s`

7. After Month 2+, enforce DMARC:
   - Update to: `v=DMARC1; p=reject; rua=mailto:dmarc@nammaoorunews.com; pct=100; adkim=s; aspf=s`
