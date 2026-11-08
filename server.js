const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3080;

const REGIONS = [
  {
    id: 'vn', name: 'Việt Nam', flag: '🇻🇳', currencyCode: 'VND', decimalSeparator: ',', hasDecimals: false,
    billing: { street: '123 Lê Lợi, Quận 1', city: 'Hồ Chí Minh', state: 'Hồ Chí Minh', zip: '700000', phone: '0901234567' }
  },
  {
    id: 'tr', name: 'Thổ Nhĩ Kỳ', flag: '🇹🇷', currencyCode: 'TRY', decimalSeparator: ',', hasDecimals: true,
    billing: { street: 'Istiklal Cad. No 45 Beyoglu', city: 'Istanbul', state: 'Istanbul', zip: '34430', phone: '5321234567' }
  },
  {
    id: 'ng', name: 'Nigeria', flag: '🇳🇬', currencyCode: 'NGN', decimalSeparator: '.', hasDecimals: true,
    billing: { street: '14 Ahmadu Bello Way, Victoria Island', city: 'Lagos', state: 'Lagos', zip: '101241', phone: '8031234567' }
  },
  {
    id: 'eg', name: 'Ai Cập', flag: '🇪🇬', currencyCode: 'EGP', decimalSeparator: '.', hasDecimals: true,
    billing: { street: '22 Tahrir Square, Downtown', city: 'Cairo', state: 'Cairo', zip: '11511', phone: '1001234567' }
  },
  {
    id: 'in', name: 'Ấn Độ', flag: '🇮🇳', currencyCode: 'INR', decimalSeparator: '.', hasDecimals: true,
    billing: { street: '42 MG Road, Connaught Place', city: 'New Delhi', state: 'Delhi', zip: '110001', phone: '9810123456' }
  },
  {
    id: 'pk', name: 'Pakistan', flag: '🇵🇰', currencyCode: 'PKR', decimalSeparator: '.', hasDecimals: true,
    billing: { street: '18 Main Boulevard Gulberg', city: 'Lahore', state: 'Punjab', zip: '54660', phone: '3001234567' }
  },
  {
    id: 'br', name: 'Brazil', flag: '🇧🇷', currencyCode: 'BRL', decimalSeparator: ',', hasDecimals: true,
    billing: { street: 'Av. Paulista 1578, Bela Vista', city: 'Sao Paulo', state: 'SP', zip: '01310-200', phone: '11987654321' }
  },
  {
    id: 'id', name: 'Indonesia', flag: '🇮🇩', currencyCode: 'IDR', decimalSeparator: ',', hasDecimals: false,
    billing: { street: 'Jl. MH Thamrin No. 10', city: 'Jakarta Pusat', state: 'DKI Jakarta', zip: '10310', phone: '81234567890' }
  },
  {
    id: 'ph', name: 'Philippines', flag: '🇵🇭', currencyCode: 'PHP', decimalSeparator: '.', hasDecimals: true,
    billing: { street: '6750 Ayala Avenue', city: 'Makati', state: 'Metro Manila', zip: '1226', phone: '9171234567' }
  },
  {
    id: 'us', name: 'Mỹ (US - Miễn thuế)', flag: '🇺🇸', currencyCode: 'USD', decimalSeparator: '.', hasDecimals: true,
    billing: { street: '700 SW 5th Ave', city: 'Portland', state: 'OR (Oregon - 0% Tax)', zip: '97204', phone: '5035550199' }
  }
];

let ratesToVND = {
  VND: 1.0,
  USD: 25450.0,
  TRY: 740.0,
  NGN: 15.8,
  EGP: 515.0,
  INR: 301.0,
  PKR: 91.5,
  BRL: 4400.0,
  IDR: 1.61,
  PHP: 438.0
};

let lastRateFetch = 0;

async function refreshRatesIfNeeded() {
  if (Date.now() - lastRateFetch < 3600 * 1000) return;
  try {
    const res = await fetch('https://open.er-api.com/v6/latest/USD', { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return;
    const data = await res.json();
    const usdToVnd = data?.rates?.VND;
    if (usdToVnd && usdToVnd > 0) {
      const updated = { VND: 1.0, USD: usdToVnd };
      for (const [code, rate] of Object.entries(data.rates)) {
        if (rate > 0) updated[code] = usdToVnd / rate;
      }
      ratesToVND = updated;
      lastRateFetch = Date.now();
    }
  } catch (_) {}
}

function parseNumericPrice(rawPrice, region) {
  if (!rawPrice) return null;
  const trimmed = rawPrice.trim();
  const lower = trimmed.toLowerCase();
  if (['free', 'miễn phí', 'ücretsiz', 'gratis'].includes(lower)) return 0;

  let multiplier = 1.0;
  if (lower.includes('juta') || lower.includes('jt')) {
    multiplier = 1000000.0;
  } else if (lower.includes('ribu') || lower.includes('rb')) {
    multiplier = 1000.0;
  }

  if (!region.hasDecimals && multiplier === 1.0) {
    const digits = trimmed.replace(/[^\d]/g, '');
    return digits ? Number(digits) : null;
  }

  let cleaned = trimmed.replace(/[^0-9.,]/g, '');
  if (!cleaned) return null;

  if (region.decimalSeparator === ',') {
    cleaned = cleaned.replace(/\./g, '').replace(/,/g, '.');
  } else {
    cleaned = cleaned.replace(/,/g, '');
  }
  const val = Number(cleaned);
  return Number.isFinite(val) ? val * multiplier : null;
}

function formatVND(vnd) {
  if (vnd === null || vnd === undefined || !Number.isFinite(vnd)) return 'Chưa rõ';
  return Math.round(vnd).toLocaleString('vi-VN') + 'đ';
}

function extractTextPairsFromHTML(html) {
  const match = html.match(/<script[^>]*id="serialized-server-data"[^>]*>([\s\S]*?)<\/script>/i);
  if (!match) return [];
  try {
    const root = JSON.parse(match[1]);
    const results = [];
    function walk(node) {
      if (!node || typeof node !== 'object') return;
      if (node.$kind === 'textPair' && node.leadingText && node.trailingText) {
        results.push({ title: String(node.leadingText), price: String(node.trailingText) });
        return;
      }
      if (Array.isArray(node)) {
        for (const item of node) walk(item);
      } else {
        for (const val of Object.values(node)) walk(val);
      }
    }
    walk(root);
    return results;
  } catch (_) {
    return [];
  }
}

async function fetchIAPForRegion(appId, region) {
  await refreshRatesIfNeeded();
  const url = `https://apps.apple.com/${region.id}/app/id${appId}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
      'Accept-Language': 'en-US,en;q=0.9'
    },
    redirect: 'manual',
    signal: AbortSignal.timeout(12000)
  });

  if (res.status >= 300 && res.status < 400) {
    const loc = res.headers.get('location') || '';
    if (loc.startsWith('http')) {
      const res2 = await fetch(loc, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
          'Accept-Language': 'en-US,en;q=0.9'
        },
        signal: AbortSignal.timeout(12000)
      });
      const html2 = await res2.text();
      return buildOfferItems(extractTextPairsFromHTML(html2), region);
    }
    return [];
  }

  const html = await res.text();
  return buildOfferItems(extractTextPairsFromHTML(html), region);
}

function buildOfferItems(pairs, region) {
  const rate = ratesToVND[region.currencyCode] || 1;
  return pairs.map((p, idx) => {
    const numericPrice = parseNumericPrice(p.price, region);
    const priceInVND = numericPrice !== null ? (region.currencyCode === 'VND' ? numericPrice : numericPrice * rate) : null;
    return {
      id: `${region.id}_${idx}_${p.title}`,
      title: p.title,
      rawPrice: p.price,
      numericPrice,
      priceInVND,
      formattedVND: formatVND(priceInVND),
      region,
      rankIndex: idx + 1
    };
  });
}

function groupOffers(offers) {
  const map = new Map();
  for (const offer of offers) {
    const key = offer.title.trim().toLowerCase();
    if (!map.has(key)) {
      map.set(key, { id: key, title: offer.title, offers: [] });
    }
    map.get(key).offers.push(offer);
  }

  const groups = [];
  for (const g of map.values()) {
    g.offers.sort((a, b) => (a.priceInVND ?? Infinity) - (b.priceInVND ?? Infinity));
    const distinctPrices = new Set(g.offers.map(o => o.rawPrice));
    g.hasHiddenPriceTiers = distinctPrices.size > 1;
    const minVND = g.offers[0]?.priceInVND;
    const maxVND = g.offers[g.offers.length - 1]?.priceInVND;
    if (g.hasHiddenPriceTiers && minVND && maxVND && maxVND > minVND) {
      g.maxSavingsPercentage = Math.round(((maxVND - minVND) / maxVND) * 100);
      g.maxSavingsVNDString = formatVND(maxVND - minVND);
    } else {
      g.maxSavingsPercentage = null;
      g.maxSavingsVNDString = null;
    }
    groups.push(g);
  }

  groups.sort((a, b) => {
    if (a.hasHiddenPriceTiers !== b.hasHiddenPriceTiers) {
      return a.hasHiddenPriceTiers ? -1 : 1;
    }
    return (a.offers[0]?.priceInVND ?? Infinity) - (b.offers[0]?.priceInVND ?? Infinity);
  });

  return groups;
}

async function handleApi(req, res, parsedUrl) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');

  const pathname = parsedUrl.pathname;

  if (pathname === '/api/regions') {
    await refreshRatesIfNeeded();
    res.end(JSON.stringify({ regions: REGIONS, ratesToVND }));
    return;
  }

  if (pathname === '/api/search') {
    const q = (parsedUrl.searchParams.get('q') || '').trim();
    const country = parsedUrl.searchParams.get('country') || 'vn';
    if (!q) {
      res.end(JSON.stringify({ results: [] }));
      return;
    }

    const idMatch = q.match(/^\d{6,15}$/) ? q : (q.match(/id(\d{6,15})/i)?.[1] || null);
    if (idMatch) {
      let r = await fetch(`https://itunes.apple.com/lookup?id=${idMatch}&country=${country}`);
      let d = await r.json();
      if (!d.results?.length) {
        r = await fetch(`https://itunes.apple.com/lookup?id=${idMatch}&country=us`);
        d = await r.json();
      }
      res.end(JSON.stringify({ results: d.results || [] }));
      return;
    }

    const searchUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(q)}&country=${country}&entity=software&limit=18`;
    const r = await fetch(searchUrl);
    const d = await r.json();
    res.end(JSON.stringify({ results: d.results || [] }));
    return;
  }

  if (pathname === '/api/iap') {
    const appId = parsedUrl.searchParams.get('appId');
    const country = parsedUrl.searchParams.get('country') || 'vn';
    const region = REGIONS.find(r => r.id === country) || REGIONS[0];
    const offers = await fetchIAPForRegion(appId, region);
    const groups = groupOffers(offers);
    res.end(JSON.stringify({ region, offers, groups }));
    return;
  }

  if (pathname === '/api/multi') {
    const appId = parsedUrl.searchParams.get('appId');
    const results = await Promise.all(
      REGIONS.map(async (region) => {
        try {
          const offers = await fetchIAPForRegion(appId, region);
          const cheapest = offers.reduce((min, o) => ((o.priceInVND ?? Infinity) < (min?.priceInVND ?? Infinity) ? o : min), null);
          return { region, offers, cheapest };
        } catch (err) {
          return { region, offers: [], cheapest: null, error: err.message };
        }
      })
    );
    results.sort((a, b) => (a.cheapest?.priceInVND ?? Infinity) - (b.cheapest?.priceInVND ?? Infinity));
    res.end(JSON.stringify({ results }));
    return;
  }

  res.statusCode = 404;
  res.end(JSON.stringify({ error: 'Not found' }));
}

function generateMobileConfig(appUrl) {
  let iconTag = '';
  try {
    const iconBytes = fs.readFileSync(path.join(__dirname, 'public', 'icon.png'));
    const b64 = iconBytes.toString('base64');
    iconTag = `\n            <key>Icon</key>\n            <data>${b64}</data>`;
  } catch (_) {}

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>FullScreen</key>
            <true/>${iconTag}
            <key>IsRemovable</key>
            <true/>
            <key>Label</key>
            <string>IAP Hunter</string>
            <key>PayloadDescription</key>
            <string>Cài đặt ứng dụng IAP Hunter ra Màn hình chính iOS</string>
            <key>PayloadDisplayName</key>
            <string>IAP Hunter iOS</string>
            <key>PayloadIdentifier</key>
            <string>com.personal.iaphunter.webclip</string>
            <key>PayloadType</key>
            <string>com.apple.webClip.managed</string>
            <key>PayloadUUID</key>
            <string>8A7E5B24-9F11-4E3A-B82D-19C4A5F01928</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>Precomposed</key>
            <true/>
            <key>URL</key>
            <string>${appUrl}</string>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>Cài đặt trực tiếp ứng dụng kiểm tra IAP ẩn (Google One, Duolingo, Tinder, CapCut...) và đổi vùng nhanh lên màn hình chính iPhone.</string>
    <key>PayloadDisplayName</key>
    <string>IAP Hunter iOS (Kèm Icon Chuẩn)</string>
    <key>PayloadIdentifier</key>
    <string>com.personal.iaphunter.profile</string>
    <key>PayloadOrganization</key>
    <string>IAP Hunter iOS</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>2F9D8C71-3E44-4A12-9B61-7D8E5F102938</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>`;
}

const server = http.createServer(async (req, res) => {
  try {
    const proto = req.headers['x-forwarded-proto'] || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers.host || `localhost:${PORT}`;
    const baseUrl = `${proto}://${host}`;
    const parsedUrl = new URL(req.url, baseUrl);

    if (parsedUrl.pathname.startsWith('/api/')) {
      await handleApi(req, res, parsedUrl);
      return;
    }

    if (parsedUrl.pathname === '/icon.png') {
      const iconPath = path.join(__dirname, 'public', 'icon.png');
      const img = fs.readFileSync(iconPath);
      res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=86400' });
      res.end(img);
      return;
    }

    if (parsedUrl.pathname === '/install.mobileconfig') {
      const configXml = generateMobileConfig(baseUrl + '/');
      res.writeHead(200, {
        'Content-Type': 'application/x-apple-aspen-config; charset=utf-8',
        'Content-Disposition': 'attachment; filename="IAPHunter.mobileconfig"'
      });
      res.end(configXml);
      return;
    }

    const htmlPath = path.join(__dirname, 'public', 'index.html');
    const html = fs.readFileSync(htmlPath, 'utf8');
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`IAP Hunter iOS Server running at http://localhost:${PORT}`);
});
