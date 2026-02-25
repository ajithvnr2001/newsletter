// Helper script to manage Cloudflare DNS records using wrangler's stored OAuth credentials
// Usage: node scripts/cf-dns.js [list|add-spf|add-dmarc|add-mx]

const { execSync } = require('child_process');
const https = require('https');

const ACCOUNT_ID = '2c24cd949c0dadc7b46ff84cd09e6c08';
const DOMAIN = 'quoteviral.online';
const MAIL_IP = '95.217.13.142';

// Get OAuth token from wrangler's config
function getAuthToken() {
  // Try to read from wrangler's token store
  const locations = [
    `${process.env.LOCALAPPDATA}\\wrangler\\config\\default.toml`,
    `${process.env.APPDATA}\\wrangler\\config\\default.toml`,
    `${process.env.HOME || process.env.USERPROFILE}\\.config\\wrangler\\config\\default.toml`,
  ];
  const fs = require('fs');
  for (const loc of locations) {
    try {
      const content = fs.readFileSync(loc, 'utf-8');
      const match = content.match(/oauth_token\s*=\s*"([^"]+)"/);
      if (match) return match[1];
    } catch (_) {}
  }
  // Fallback: use CLOUDFLARE_API_TOKEN env var
  if (process.env.CLOUDFLARE_API_TOKEN && process.env.CLOUDFLARE_API_TOKEN !== 'CHANGE_ME') {
    return process.env.CLOUDFLARE_API_TOKEN;
  }
  return null;
}

function cfApi(method, path, body) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.cloudflare.com',
      path: `/client/v4${path}`,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const token = getAuthToken();
    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve({ raw: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function getZoneId() {
  const resp = await cfApi('GET', `/zones?name=${DOMAIN}`);
  if (resp.result && resp.result.length > 0) {
    return resp.result[0].id;
  }
  throw new Error(`Zone ${DOMAIN} not found. Response: ${JSON.stringify(resp)}`);
}

async function listDns(zoneId) {
  const resp = await cfApi('GET', `/zones/${zoneId}/dns_records?per_page=100`);
  return resp.result || [];
}

async function createDns(zoneId, record) {
  return cfApi('POST', `/zones/${zoneId}/dns_records`, record);
}

async function main() {
  const action = process.argv[2] || 'list';

  const token = getAuthToken();
  if (!token) {
    console.error('ERROR: No Cloudflare API token found.');
    console.error('Set CLOUDFLARE_API_TOKEN env var or run: wrangler login');
    process.exit(1);
  }

  let zoneId;
  try {
    zoneId = await getZoneId();
    console.log(`Zone ID: ${zoneId}`);
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }

  if (action === 'list') {
    const records = await listDns(zoneId);
    records.forEach(r => {
      console.log(`${r.type.padEnd(6)} ${r.name.padEnd(40)} ${(r.content || '').substring(0, 80)}`);
    });
  }

  if (action === 'add-spf') {
    const resp = await createDns(zoneId, {
      type: 'TXT', name: DOMAIN, content: `v=spf1 ip4:${MAIL_IP} ~all`, ttl: 3600
    });
    console.log('SPF:', resp.success ? 'CREATED' : JSON.stringify(resp.errors));
  }

  if (action === 'add-dmarc') {
    const resp = await createDns(zoneId, {
      type: 'TXT', name: `_dmarc.${DOMAIN}`,
      content: 'v=DMARC1; p=none; rua=mailto:dmarc@quoteviral.online; pct=100; adkim=r; aspf=r',
      ttl: 3600
    });
    console.log('DMARC:', resp.success ? 'CREATED' : JSON.stringify(resp.errors));
  }

  if (action === 'add-mx') {
    const resp = await createDns(zoneId, {
      type: 'MX', name: DOMAIN, content: `mail.${DOMAIN}`, priority: 10, ttl: 3600
    });
    console.log('MX:', resp.success ? 'CREATED' : JSON.stringify(resp.errors));
  }

  if (action === 'add-mail-a') {
    const resp = await createDns(zoneId, {
      type: 'A', name: `mail.${DOMAIN}`, content: MAIL_IP, proxied: false, ttl: 3600
    });
    console.log('A (mail):', resp.success ? 'CREATED' : JSON.stringify(resp.errors));
  }

  if (action === 'add-all') {
    console.log('Creating all DNS records...');
    // SPF
    let r = await createDns(zoneId, {
      type: 'TXT', name: DOMAIN, content: `v=spf1 ip4:${MAIL_IP} ~all`, ttl: 3600
    });
    console.log('SPF:', r.success ? '✅ CREATED' : `❌ ${JSON.stringify(r.errors)}`);
    // DMARC
    r = await createDns(zoneId, {
      type: 'TXT', name: `_dmarc.${DOMAIN}`,
      content: 'v=DMARC1; p=none; rua=mailto:dmarc@quoteviral.online; pct=100; adkim=r; aspf=r',
      ttl: 3600
    });
    console.log('DMARC:', r.success ? '✅ CREATED' : `❌ ${JSON.stringify(r.errors)}`);
    // MX
    r = await createDns(zoneId, {
      type: 'MX', name: DOMAIN, content: `mail.${DOMAIN}`, priority: 10, ttl: 3600
    });
    console.log('MX:', r.success ? '✅ CREATED' : `❌ ${JSON.stringify(r.errors)}`);
    // A record for mail subdomain
    r = await createDns(zoneId, {
      type: 'A', name: `mail.${DOMAIN}`, content: MAIL_IP, proxied: false, ttl: 3600
    });
    console.log('A (mail):', r.success ? '✅ CREATED' : `❌ ${JSON.stringify(r.errors)}`);

    console.log('\nZone ID:', zoneId);
    console.log('NOTE: DKIM record needs to be added after key generation on the server.');
  }
}

main().catch(console.error);
