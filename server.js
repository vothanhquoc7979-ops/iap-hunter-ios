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

// Deep Link mở thẳng màn hình Thanh toán / Upgrade của từng App trên iOS
const APP_PAYWALL_DEEPLINKS = {
  '1451784328': { scheme: 'googleone://upgrade', webUrl: 'https://one.google.com/plans', appName: 'Google One' },
  '6477489729': { scheme: 'googlegemini://', webUrl: 'https://gemini.google.com/upgrade', appName: 'Google Gemini' },
  '284815942':  { scheme: 'googleapp://', webUrl: 'https://one.google.com/plans', appName: 'Google App' },
  '842842640':  { scheme: 'googledocs://', webUrl: 'https://one.google.com/plans', appName: 'Google Docs' },
  '909319292':  { scheme: 'googlecalendar://', webUrl: 'https://one.google.com/plans', appName: 'Google Calendar' },
  '962194608':  { scheme: 'googlephotos://', webUrl: 'https://one.google.com/plans', appName: 'Google Photos' },
  '544007664':  { scheme: 'youtube://www.youtube.com/premium', webUrl: 'https://www.youtube.com/premium', appName: 'YouTube' },
  '1017492454': { scheme: 'youtubemusic://', webUrl: 'https://music.youtube.com/music_premium', appName: 'YouTube Music' },
  '6473753684': { scheme: 'claude://', webUrl: 'https://claude.ai/upgrade', appName: 'Claude AI' },
  '6448311069': { scheme: 'chatgpt://', webUrl: 'https://chatgpt.com/#pricing', appName: 'ChatGPT' },
  '570060128':  { scheme: 'duolingo://', webUrl: 'https://www.duolingo.com/super', appName: 'Duolingo' },
  '547702041':  { scheme: 'tinder://', webUrl: 'https://tinder.com/app/profile', appName: 'Tinder' },
  '1500855883': { scheme: 'capcut://', webUrl: 'https://www.capcut.com', appName: 'CapCut' },
  '897446215':  { scheme: 'canva://', webUrl: 'https://www.canva.com/pricing', appName: 'Canva' },
  '1600525061': { scheme: 'locket://', webUrl: 'https://locket.camera', appName: 'Locket Widget' }
};

// Nhóm các App vệ tinh dùng chung gói Subscription ẩn (Companion Ecosystem Apps)
const ECOSYSTEM_COMPANIONS = {
  '1451784328': [
    { id: '1451784328', name: 'Google One', isPrimary: true },
    { id: '6477489729', name: 'Google Gemini (Chứa AI Pro & Ultra)', isPrimary: false },
    { id: '284815942',  name: 'Google App (Chứa AI Ultra x5 20TB & x20 30TB)', isPrimary: false },
    { id: '842842640',  name: 'Google Docs (Chứa AI Pro 5TB Năm)', isPrimary: false },
    { id: '909319292',  name: 'Google Calendar (Chứa 30GB & AI Plus Năm)', isPrimary: false },
    { id: '962194608',  name: 'Google Photos', isPrimary: false }
  ],
  '6477489729': [
    { id: '6477489729', name: 'Google Gemini', isPrimary: true },
    { id: '284815942',  name: 'Google App (Chứa AI Ultra x5 20TB & x20 30TB)', isPrimary: false },
    { id: '1451784328', name: 'Google One', isPrimary: false },
    { id: '842842640',  name: 'Google Docs (Chứa AI Pro 5TB Năm)', isPrimary: false },
    { id: '909319292',  name: 'Google Calendar (Chứa 30GB & AI Plus Năm)', isPrimary: false }
  ],
  '544007664': [
    { id: '544007664',  name: 'YouTube', isPrimary: true },
    { id: '1017492454', name: 'YouTube Music (Chứa gói Family ẩn 139k)', isPrimary: false }
  ]
};

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

function normalizeOfferTitle(title, appId) {
  let t = String(title).trim();
  if (t.includes('Google AI Ultra (20 TB)') && !t.includes('x5')) {
    t = 'Google AI Ultra x5 (20 TB)';
  } else if (t.includes('Google AI Ultra (30 TB)') && !t.includes('x20')) {
    t = 'Google AI Ultra x20 (30 TB)';
  }
  if (String(appId) === '6473753684') {
    if (t.includes('Claude Max') && !t.includes('x5')) {
      t = t.replace('Claude Max', 'Claude Max (Gói x5)');
    } else if (t.includes('Claude Ultra') && !t.includes('x20')) {
      t = t.replace('Claude Ultra', 'Claude Ultra (Gói x20)');
    }
  }
  return t;
}

function extractTextPairsFromHTML(html, appId) {
  const match = html.match(/<script[^>]*id="serialized-server-data"[^>]*>([\s\S]*?)<\/script>/i);
  if (!match) return [];
  try {
    const root = JSON.parse(match[1]);
    const results = [];
    function walk(node) {
      if (!node || typeof node !== 'object') return;
      if (node.$kind === 'textPair' && node.leadingText && node.trailingText) {
        results.push({
          title: normalizeOfferTitle(node.leadingText, appId),
          price: String(node.trailingText)
        });
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

async function fetchSingleAppPairs(appId, region, sourceLabel = null, isHiddenCompanion = false) {
  const url = `https://apps.apple.com/${region.id}/app/id${appId}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
      'Accept-Language': 'en-US,en;q=0.9'
    },
    redirect: 'manual',
    signal: AbortSignal.timeout(12000)
  });

  let html = '';
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
      html = await res2.text();
    } else {
      return [];
    }
  } else {
    html = await res.text();
  }

  return extractTextPairsFromHTML(html, appId).map(p => ({
    ...p,
    sourceAppId: String(appId),
    sourceApp: sourceLabel,
    isHiddenCompanion
  }));
}

async function fetchIAPForRegion(appId, region, includeGlobalUncovered = false) {
  await refreshRatesIfNeeded();
  const idStr = String(appId);
  const companions = ECOSYSTEM_COMPANIONS[idStr];

  let allPairs = [];
  if (companions) {
    const lists = await Promise.all(
      companions.map(c =>
        fetchSingleAppPairs(c.id, region, c.name, !c.isPrimary).catch(() => [])
      )
    );
    allPairs = lists.flat();
  } else {
    allPairs = await fetchSingleAppPairs(idStr, region, null, false);
  }

  let items = buildOfferItems(allPairs, region, idStr);

  if (includeGlobalUncovered) {
    const existingTitles = new Set(items.map(i => i.title.toLowerCase()));
    const probeRegions = ['tr', 'us', 'eg', 'ph'].filter(rId => rId !== region.id);
    const probeRegionObjs = probeRegions.map(rId => REGIONS.find(r => r.id === rId)).filter(Boolean);

    const probeResults = await Promise.all(
      probeRegionObjs.map(async (pReg) => {
        try {
          if (companions) {
            const subLists = await Promise.all(
              companions.slice(0, 3).map(c =>
                fetchSingleAppPairs(c.id, pReg, `${c.name} • Vùng ${pReg.flag} ${pReg.name}`, true).catch(() => [])
              )
            );
            return buildOfferItems(subLists.flat(), pReg, idStr);
          } else {
            const sub = await fetchSingleAppPairs(idStr, pReg, `Ẩn tại Store ${pReg.flag} ${pReg.name}`, true).catch(() => []);
            return buildOfferItems(sub, pReg, idStr);
          }
        } catch (_) {
          return [];
        }
      })
    );

    const uncoveredItems = [];
    for (const pList of probeResults) {
      for (const offer of pList) {
        const key = offer.title.toLowerCase();
        if (!existingTitles.has(key)) {
          uncoveredItems.push({
            ...offer,
            isUncoveredFromOtherRegion: true,
            sourceApp: offer.sourceApp || `Ẩn trên Store ${region.name} (Phát hiện tại ${offer.region.flag} ${offer.region.name})`
          });
        }
      }
    }
    items = [...items, ...uncoveredItems];
  }

  return items;
}

function buildOfferItems(pairs, region, fallbackAppId) {
  const rate = ratesToVND[region.currencyCode] || 1;
  return pairs.map((p, idx) => {
    const numericPrice = parseNumericPrice(p.price, region);
    const priceInVND = numericPrice !== null ? (region.currencyCode === 'VND' ? numericPrice : numericPrice * rate) : null;
    const targetAppId = p.sourceAppId || String(fallbackAppId);
    const dlInfo = APP_PAYWALL_DEEPLINKS[targetAppId] || {};

    return {
      id: `${region.id}_${idx}_${p.title}_${p.price}`,
      title: p.title,
      rawPrice: p.price,
      numericPrice,
      priceInVND,
      formattedVND: formatVND(priceInVND),
      region,
      rankIndex: idx + 1,
      sourceAppId: targetAppId,
      sourceAppName: dlInfo.appName || p.sourceApp || 'Ứng dụng gốc',
      sourceApp: p.sourceApp || null,
      appSchemeUrl: dlInfo.scheme || `itms-apps://itunes.apple.com/${region.id}/app/id${targetAppId}?mt=8`,
      appPaywallWebUrl: dlInfo.webUrl || `https://apps.apple.com/${region.id}/app/id${targetAppId}`,
      appleSubscriptionUrl: `itms-apps://apps.apple.com/account/subscriptions?app-id=${targetAppId}`,
      storeAppUrl: `itms-apps://itunes.apple.com/${region.id}/app/id${targetAppId}?mt=8`,
      isHiddenCompanion: Boolean(p.isHiddenCompanion),
      isUncoveredFromOtherRegion: Boolean(p.isUncoveredFromOtherRegion)
    };
  });
}

function deduplicateOffers(offers) {
  const seen = new Set();
  const unique = [];
  for (const o of offers) {
    const key = `${o.region.id}|${o.title.toLowerCase()}|${o.rawPrice}`;
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(o);
    }
  }
  unique.sort((a, b) => (a.priceInVND ?? Infinity) - (b.priceInVND ?? Infinity));
  return unique;
}

function groupOffers(offers) {
  const map = new Map();
  for (const offer of deduplicateOffers(offers)) {
    const key = offer.title.trim().toLowerCase();
    if (!map.has(key)) {
      map.set(key, {
        id: key,
        title: offer.title,
        offers: [],
        isDeepHidden: false
      });
    }
    const g = map.get(key);
    g.offers.push(offer);
    if (offer.isHiddenCompanion || offer.isUncoveredFromOtherRegion) {
      g.isDeepHidden = true;
    }
  }

  const groups = [];
  for (const g of map.values()) {
    g.offers.sort((a, b) => (a.priceInVND ?? Infinity) - (b.priceInVND ?? Infinity));
    const distinctPrices = new Set(g.offers.map(o => `${o.rawPrice}`));
    g.hasHiddenPriceTiers = distinctPrices.size > 1 || g.isDeepHidden;
    const minVND = g.offers[0]?.priceInVND;
    const maxVND = g.offers[g.offers.length - 1]?.priceInVND;
    if (distinctPrices.size > 1 && minVND && maxVND && maxVND > minVND) {
      g.maxSavingsPercentage = Math.round(((maxVND - minVND) / maxVND) * 100);
      g.maxSavingsVNDString = formatVND(maxVND - minVND);
    } else {
      g.maxSavingsPercentage = null;
      g.maxSavingsVNDString = null;
    }
    groups.push(g);
  }

  groups.sort((a, b) => {
    const aIsAI = a.title.includes('AI Ultra') || a.title.includes('AI Pro') || a.title.includes('x5') || a.title.includes('x20');
    const bIsAI = b.title.includes('AI Ultra') || b.title.includes('AI Pro') || b.title.includes('x5') || b.title.includes('x20');
    if (aIsAI !== bIsAI) return aIsAI ? -1 : 1;
    if (a.isDeepHidden !== b.isDeepHidden) return a.isDeepHidden ? -1 : 1;
    if (a.hasHiddenPriceTiers !== b.hasHiddenPriceTiers) return a.hasHiddenPriceTiers ? -1 : 1;
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
    const offers = await fetchIAPForRegion(appId, region, true);
    const groups = groupOffers(offers);
    res.end(JSON.stringify({ region, offers, groups }));
    return;
  }

  if (pathname === '/api/multi') {
    const appId = parsedUrl.searchParams.get('appId');
    const results = await Promise.all(
      REGIONS.map(async (region) => {
        try {
          const rawOffers = await fetchIAPForRegion(appId, region, false);
          const offers = deduplicateOffers(rawOffers);
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
    <string>Cài đặt trực tiếp ứng dụng kiểm tra IAP ẩn (Google One, AI Pro/Ultra x5/x20, Claude, ChatGPT...) lên màn hình chính iPhone.</string>
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
