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

// Deep Link mở thẳng màn hình Thanh toán / Upgrade + Bundle ID & StoreKit SKU của từng App trên iOS
const APP_PAYWALL_DEEPLINKS = {
  '1451784328': { scheme: 'googleone://', bundleId: 'com.google.GoogleOne', skuPrefix: 'com.google.one', webUrl: 'https://one.google.com/plans', appName: 'Google One' },
  '6477489729': { scheme: 'googlegemini://', bundleId: 'com.google.gemini', skuPrefix: 'com.google.gemini', webUrl: 'https://gemini.google.com/upgrade', appName: 'Google Gemini' },
  '284815942':  { scheme: 'google://', bundleId: 'com.google.GoogleMobile', skuPrefix: 'com.google.one.ai', webUrl: 'https://one.google.com/plans', appName: 'Google App' },
  '842842640':  { scheme: 'googledocs://', bundleId: 'com.google.Docs', skuPrefix: 'com.google.one.ai', webUrl: 'https://one.google.com/plans', appName: 'Google Docs' },
  '909319292':  { scheme: 'googlecalendar://', bundleId: 'com.google.calendar', skuPrefix: 'com.google.one', webUrl: 'https://one.google.com/plans', appName: 'Google Calendar' },
  '962194608':  { scheme: 'googlephotos://', bundleId: 'com.google.photos', skuPrefix: 'com.google.one', webUrl: 'https://one.google.com/plans', appName: 'Google Photos' },
  '544007664':  { scheme: 'vnd.youtube://www.youtube.com/premium', bundleId: 'com.google.ios.youtube', skuPrefix: 'com.google.ios.youtube.premium', webUrl: 'https://www.youtube.com/premium', appName: 'YouTube' },
  '1017492454': { scheme: 'youtubemusic://', bundleId: 'com.google.ios.youtubemusic', skuPrefix: 'com.google.ios.youtubemusic.premium', webUrl: 'https://music.youtube.com/music_premium', appName: 'YouTube Music' },
  '6473753684': { scheme: 'claude://', bundleId: 'com.anthropic.claude', skuPrefix: 'com.anthropic.claude', webUrl: 'https://claude.ai/upgrade', appName: 'Claude AI' },
  '6448311069': { scheme: 'chatgpt://', bundleId: 'com.openai.chat', skuPrefix: 'com.openai.chat', webUrl: 'https://chatgpt.com/#pricing', appName: 'ChatGPT' },
  '570060128':  { scheme: 'duolingo://', bundleId: 'com.duolingo.DuolingoMobile', skuPrefix: 'com.duolingo.super', webUrl: 'https://www.duolingo.com/super', appName: 'Duolingo' },
  '547702041':  { scheme: 'tinder://', bundleId: 'com.cardify.tinder', skuPrefix: 'com.cardify.tinder', webUrl: 'https://tinder.com/app/profile', appName: 'Tinder' },
  '1500855883': { scheme: 'capcut://', bundleId: 'com.lemon.lvoverseas', skuPrefix: 'com.lemon.lvoverseas', webUrl: 'https://www.capcut.com', appName: 'CapCut' },
  '897446215':  { scheme: 'canva://', bundleId: 'com.canva.canvaeditor', skuPrefix: 'com.canva.pro', webUrl: 'https://www.canva.com/pricing', appName: 'Canva' },
  '1600525061': { scheme: 'locket://', bundleId: 'com.locket.Locket', skuPrefix: 'com.locket.gold', webUrl: 'https://locket.camera', appName: 'Locket Widget' }
};

// Kho dữ liệu StoreKit SKU Sâu: Chứa các gói GIẢM KỲ ĐẦU (Introductory Offer) & GÓI ẨN (Hidden SKUs) trong Binary/StoreKit
const GOOGLE_AI_DEEP_OFFERS = [
  {
    title: 'Google AI Ultra (30 TB)',
    sku: 'com.google.gemini.ai.ultra.30tb.intro3m',
    sourceAppId: '6477489729',
    sourceLabel: 'Google Gemini • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
    isIntroOffer: true,
    isHiddenSku: true,
    introPeriod: 'Ưu đãi 3 tháng',
    pricesByRegion: {
      vn: '1.949.000đ', tr: '₺1.049,99', ng: '₦ 99,900.00', eg: 'EGP 1,049.99',
      pk: 'Rs 19,500.00', br: 'R$ 349,90', id: 'Rp 1,19juta', ph: '₱ 4,190.00', us: '$69.99'
    },
    renewByRegion: {
      vn: '5.500.000đ/tháng', tr: '₺2.949,99/tháng', ng: '₦ 285,000.00/tháng', eg: 'EGP 2,949.99/tháng',
      pk: 'Rs 55,900.00/tháng', br: 'R$ 999,90/tháng', id: 'Rp 3,39juta/tháng', ph: '₱ 11,900.00/tháng', us: '$199.99/tháng'
    }
  },
  {
    title: 'Google AI Ultra (30 TB) [Giá Chuẩn Ẩn]',
    sku: 'com.google.gemini.ai.ultra.30tb.monthly',
    sourceAppId: '6477489729',
    sourceLabel: 'Google Gemini • Gói Ẩn StoreKit (30 TB - Ultra x20)',
    isIntroOffer: false,
    isHiddenSku: true,
    pricesByRegion: {
      vn: '5.500.000đ', tr: '₺2.949,99', ng: '₦ 285,000.00', eg: 'EGP 2,949.99',
      pk: 'Rs 55,900.00', br: 'R$ 999,90', id: 'Rp 3,39juta', ph: '₱ 11,900.00', us: '$199.99'
    }
  },
  {
    title: 'Google AI Ultra (20 TB) [Ultra x5]',
    sku: 'com.google.gemini.ai.ultra.20tb.intro3m',
    sourceAppId: '6477489729',
    sourceLabel: 'Google Gemini • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
    isIntroOffer: true,
    isHiddenSku: true,
    introPeriod: 'Ưu đãi 3 tháng',
    pricesByRegion: {
      vn: '899.000đ', tr: '₺699,99', ng: '₦ 55,000.00', eg: 'EGP 699.99',
      pk: 'Rs 9,900.00', br: 'R$ 179,90', id: 'Rp 599ribu', ph: '₱ 1,990.00', us: '$34.99'
    },
    renewByRegion: {
      vn: '2.250.000đ/tháng', tr: '₺1.989,99/tháng', ng: '₦ 149,000.00/tháng', eg: 'EGP 1,989.99/tháng',
      pk: 'Rs 28,500.00/tháng', br: 'R$ 499,90/tháng', id: 'Rp 1,69juta/tháng', ph: '₱ 5,790.00/tháng', us: '$99.99/tháng'
    }
  },
  {
    title: 'Google AI Pro (5 TB) [Giảm Kỳ Đầu]',
    sku: 'com.google.gemini.ai.pro.5tb.intro3m',
    sourceAppId: '6477489729',
    sourceLabel: 'Google Gemini • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
    isIntroOffer: true,
    isHiddenSku: true,
    introPeriod: 'Ưu đãi 3 tháng',
    pricesByRegion: {
      vn: '169.000đ', tr: '₺189,99', ng: '₦ 9,900.00', eg: 'EGP 249.99',
      pk: 'Rs 2,100.00', br: 'R$ 34,90', id: 'Rp 109ribu', ph: '₱ 389.00', us: '$6.99'
    },
    renewByRegion: {
      vn: '489.000đ/tháng', tr: '₺539,99/tháng', ng: '₦ 28,500.00/tháng', eg: 'EGP 699.99/tháng',
      pk: 'Rs 5,900.00/tháng', br: 'R$ 96,99/tháng', id: 'Rp 309ribu/tháng', ph: '₱ 1,100.00/tháng', us: '$19.99/tháng'
    }
  },
  {
    title: 'Google AI Plus (400 GB) [Giảm Kỳ Đầu]',
    sku: 'com.google.gemini.ai.plus.400gb.intro3m',
    sourceAppId: '6477489729',
    sourceLabel: 'Google Gemini • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
    isIntroOffer: true,
    isHiddenSku: true,
    introPeriod: 'Ưu đãi 3 tháng',
    pricesByRegion: {
      vn: '33.000đ', tr: '₺49,99', ng: '₦ 1,900.00', eg: 'EGP 49.99',
      pk: 'Rs 450.00', br: 'R$ 7,90', id: 'Rp 22ribu', ph: '₱ 79.00', us: '$1.99'
    },
    renewByRegion: {
      vn: '132.000đ/tháng', tr: '₺199,99/tháng', ng: '₦ 7,900.00/tháng', eg: 'EGP 199.99/tháng',
      pk: 'Rs 1,800.00/tháng', br: 'R$ 29,90/tháng', id: 'Rp 89ribu/tháng', ph: '₱ 299.00/tháng', us: '$7.99/tháng'
    }
  }
];

const HIDDEN_STOREKIT_VAULT = {
  '1451784328': GOOGLE_AI_DEEP_OFFERS,
  '6477489729': GOOGLE_AI_DEEP_OFFERS,
  // CapCut: Các gói GIẢM KỲ ĐẦU & Gói Năm (Yearly / Annual) ẩn trong Subscription Group của CapCut
  '1500855883': [
    {
      title: 'CapCut Pro - Monthly (Ưu Đãi Kỳ Đầu)',
      sku: 'com.lemon.lvoverseas.pro.monthly.intro',
      sourceLabel: 'CapCut • GIẢM KỲ ĐẦU (Tháng đầu) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi 1 tháng đầu',
      pricesByRegion: {
        vn: '23.000đ', tr: '₺39,99', ng: '₦ 1,900.00', eg: 'EGP 69.99',
        pk: 'Rs 390.00', br: 'R$ 9,90', id: 'Rp 19ribu', ph: '₱ 69.00', us: '$1.99'
      },
      renewByRegion: {
        vn: '117.000đ/tháng', tr: '₺199,99/tháng', ng: '₦ 6,900.00/tháng', eg: 'EGP 249.99/tháng',
        pk: 'Rs 1,200.00/tháng', br: 'R$ 32,90/tháng', id: 'Rp 75ribu/tháng', ph: '₱ 250.00/tháng', us: '$9.99/tháng'
      }
    },
    {
      title: 'CapCut Standard Yearly (Gói Năm Giảm Kỳ Đầu)',
      sku: 'com.lemon.lvoverseas.standard.yearly.intro',
      sourceLabel: 'CapCut • GIẢM KỲ ĐẦU (Năm đầu) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi năm đầu',
      pricesByRegion: {
        vn: '490.000đ', tr: '₺799,99', ng: '₦ 29,900.00', eg: 'EGP 999.99',
        pk: 'Rs 4,500.00', br: 'R$ 149,90', id: 'Rp 319ribu', ph: '₱ 1,050.00', us: '$39.99'
      },
      renewByRegion: {
        vn: '700.000đ/năm', tr: '₺1.199,99/năm', ng: '₦ 44,900.00/năm', eg: 'EGP 1,499.99/năm',
        pk: 'Rs 6,900.00/năm', br: 'R$ 234,90/năm', id: 'Rp 455ribu/năm', ph: '₱ 1,520.00/năm', us: '$59.99/năm'
      }
    },
    {
      title: 'CapCut Pro - Yearly Subscription (Gói Năm Ẩn Legacy)',
      sku: 'com.lemon.lvoverseas.pro.yearly.v1',
      sourceLabel: 'IPA StoreKit Ẩn • Gói Năm Cũ (See All Plans)',
      isIntroOffer: false,
      isHiddenSku: true,
      pricesByRegion: {
        vn: '550.000đ', tr: '₺899,99', ng: '₦ 34,900.00', eg: 'EGP 1,199.99',
        pk: 'Rs 5,500.00', br: 'R$ 169,90', id: 'Rp 379ribu', ph: '₱ 1,290.00', us: '$54.99'
      }
    },
    {
      title: 'CapCut Pro - Yearly Subscription (Gói Năm Ưu Đãi Ẩn)',
      sku: 'com.lemon.lvoverseas.pro.yearly.promo',
      sourceLabel: 'CapCut • GIẢM KỲ ĐẦU (Năm đầu) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi năm đầu',
      pricesByRegion: {
        vn: '799.000đ', tr: '₺1.399,99', ng: '₦ 52,900.00', eg: 'EGP 1,799.99',
        pk: 'Rs 7,900.00', br: 'R$ 249,90', id: 'Rp 549ribu', ph: '₱ 1,850.00', us: '$69.99'
      },
      renewByRegion: {
        vn: '1.550.000đ/năm', tr: '₺2.499,99/năm', ng: '₦ 84,900.00/năm', eg: 'EGP 2,999.99/năm',
        pk: 'Rs 14,500.00/năm', br: 'R$ 429,90/năm', id: 'Rp 999ribu/năm', ph: '₱ 3,290.00/năm', us: '$89.99/năm'
      }
    },
    {
      title: 'CapCut Pro - Yearly Subscription (Gói Năm Pro Tier 2 Ẩn)',
      sku: 'com.lemon.lvoverseas.pro.yearly.tier2',
      sourceLabel: 'IPA StoreKit Ẩn • Gói Năm Pro Tier 2 (See All Plans)',
      isIntroOffer: false,
      isHiddenSku: true,
      pricesByRegion: {
        vn: '1.290.000đ', tr: '₺1.999,99', ng: '₦ 69,900.00', eg: 'EGP 2,499.99',
        pk: 'Rs 11,900.00', br: 'R$ 349,90', id: 'Rp 799ribu', ph: '₱ 2,690.00', us: '$74.99'
      }
    },
    {
      title: 'CapCut Pro - Yearly Subscription (Gói Năm Pro Chuẩn)',
      sku: 'com.lemon.lvoverseas.pro.yearly',
      sourceLabel: 'IPA StoreKit Ẩn • Gói Năm Pro Full (See All Plans)',
      isIntroOffer: false,
      isHiddenSku: true,
      pricesByRegion: {
        vn: '1.550.000đ', tr: '₺2.499,99', ng: '₦ 84,900.00', eg: 'EGP 2,999.99',
        pk: 'Rs 14,500.00', br: 'R$ 429,90', id: 'Rp 999ribu', ph: '₱ 3,290.00', us: '$89.99'
      }
    },
    {
      title: 'CapCut Pro - 1 Year Plan (Gói 1 Năm Không Gia Hạn)',
      sku: 'com.lemon.lvoverseas.pro.1year',
      sourceLabel: 'IPA StoreKit Ẩn • Gói 1 Năm Lẻ',
      isIntroOffer: false,
      isHiddenSku: true,
      pricesByRegion: {
        vn: '1.950.000đ', tr: '₺2.999,99', ng: '₦ 99,900.00', eg: 'EGP 3,499.99',
        pk: 'Rs 17,900.00', br: 'R$ 499,90', id: 'Rp 1,19juta', ph: '₱ 3,890.00', us: '$109.99'
      }
    }
  ],
  // Claude AI: Các gói Max 5x, Ultra 20x & Ưu đãi kỳ đầu ẩn
  '6473753684': [
    {
      title: 'Claude Pro (Ưu Đãi Kỳ Đầu)',
      sku: 'com.anthropic.claude.pro.monthly.intro',
      sourceLabel: 'Claude AI • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi 3 tháng',
      pricesByRegion: {
        vn: '249.000đ', tr: '₺349,99', ng: '₦ 14,900.00', eg: 'EGP 499.99',
        pk: 'Rs 2,900.00', br: 'R$ 54,90', id: 'Rp 159ribu', ph: '₱ 549.00', us: '$9.99'
      },
      renewByRegion: {
        vn: '499.000đ/tháng', tr: '₺699,99/tháng', ng: '₦ 29,900.00/tháng', eg: 'EGP 999.99/tháng',
        pk: 'Rs 5,800.00/tháng', br: 'R$ 109,90/tháng', id: 'Rp 319ribu/tháng', ph: '₱ 1,090.00/tháng', us: '$19.99/tháng'
      }
    },
    {
      title: 'Claude Max 5x (Gói Ẩn StoreKit)',
      sku: 'com.anthropic.claude.max.5x.monthly.intro',
      sourceLabel: 'Claude AI • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi 3 tháng',
      pricesByRegion: {
        vn: '1.249.000đ', tr: '₺1.749,99', ng: '₦ 74,900.00', eg: 'EGP 2,499.99',
        pk: 'Rs 14,500.00', br: 'R$ 269,90', id: 'Rp 799ribu', ph: '₱ 2,790.00', us: '$49.99'
      },
      renewByRegion: {
        vn: '2.499.000đ/tháng', tr: '₺3.499,99/tháng', ng: '₦ 149,000.00/tháng', eg: 'EGP 4,999.99/tháng',
        pk: 'Rs 29,000.00/tháng', br: 'R$ 549,90/tháng', id: 'Rp 1,59juta/tháng', ph: '₱ 5,590.00/tháng', us: '$99.99/tháng'
      }
    },
    {
      title: 'Claude Max 20x [Ultra x20]',
      sku: 'com.anthropic.claude.max.20x.monthly.intro',
      sourceLabel: 'Claude AI • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi 3 tháng',
      pricesByRegion: {
        vn: '2.499.000đ', tr: '₺3.499,99', ng: '₦ 149,000.00', eg: 'EGP 4,999.99',
        pk: 'Rs 29,000.00', br: 'R$ 549,90', id: 'Rp 1,59juta', ph: '₱ 5,590.00', us: '$99.99'
      },
      renewByRegion: {
        vn: '4.999.000đ/tháng', tr: '₺6.999,99/tháng', ng: '₦ 299,000.00/tháng', eg: 'EGP 9,999.99/tháng',
        pk: 'Rs 58,000.00/tháng', br: 'R$ 1.099,90/tháng', id: 'Rp 3,19juta/tháng', ph: '₱ 11,190.00/tháng', us: '$199.99/tháng'
      }
    }
  ],
  // ChatGPT: Gói Plus & Pro $200 ẩn + Giảm kỳ đầu
  '6448311069': [
    {
      title: 'ChatGPT Plus (Ưu Đãi Kỳ Đầu)',
      sku: 'com.openai.chat.plus.monthly.intro',
      sourceLabel: 'ChatGPT • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi 3 tháng',
      pricesByRegion: {
        vn: '249.000đ', tr: '₺349,99', ng: '₦ 9,900.00', eg: 'EGP 349.99',
        pk: 'Rs 2,900.00', br: 'R$ 49,90', id: 'Rp 159ribu', ph: '₱ 549.00', us: '$9.99'
      },
      renewByRegion: {
        vn: '499.000đ/tháng', tr: '₺699,99/tháng', ng: '₦ 19,900.00/tháng', eg: 'EGP 699.99/tháng',
        pk: 'Rs 5,800.00/tháng', br: 'R$ 99,90/tháng', id: 'Rp 319ribu/tháng', ph: '₱ 1,100.00/tháng', us: '$19.99/tháng'
      }
    },
    {
      title: 'ChatGPT Pro (Unlimited o1/GPT-4.5)',
      sku: 'com.openai.chat.pro.monthly.intro',
      sourceLabel: 'ChatGPT • GIẢM KỲ ĐẦU (Ưu đãi 3 tháng) • ẨN',
      isIntroOffer: true,
      isHiddenSku: true,
      introPeriod: 'Ưu đãi 3 tháng',
      pricesByRegion: {
        vn: '1.999.000đ', tr: '₺2.999,99', ng: '₦ 99,900.00', eg: 'EGP 3,499.99',
        pk: 'Rs 22,000.00', br: 'R$ 399,90', id: 'Rp 1,29juta', ph: '₱ 4,490.00', us: '$79.99'
      },
      renewByRegion: {
        vn: '4.999.000đ/tháng', tr: '₺6.999,99/tháng', ng: '₦ 285,000.00/tháng', eg: 'EGP 9,999.99/tháng',
        pk: 'Rs 58,000.00/tháng', br: 'R$ 999,90/tháng', id: 'Rp 3,29juta/tháng', ph: '₱ 11,490.00/tháng', us: '$199.99/tháng'
      }
    }
  ]
};

function inferStoreKitSku(appId, title, explicitSku) {
  if (explicitSku) return explicitSku;
  const dlInfo = APP_PAYWALL_DEEPLINKS[String(appId)] || {};
  const prefix = dlInfo.skuPrefix || dlInfo.bundleId || `com.app.id${appId}`;
  const slug = String(title)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^\.+|\.+$/g, '');
  return `${prefix}.${slug}`;
}

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

  // Bổ sung các gói StoreKit SKU ẩn trong Apple Subscription Group ("See All Plans") & GIẢM KỲ ĐẦU
  const vaultEntries = HIDDEN_STOREKIT_VAULT[idStr] || [];
  for (const v of vaultEntries) {
    const regionalPrice = v.pricesByRegion[region.id];
    if (regionalPrice) {
      allPairs.push({
        title: v.title,
        price: regionalPrice,
        sku: v.sku,
        sourceAppId: v.sourceAppId || idStr,
        sourceApp: v.sourceLabel,
        isHiddenCompanion: true,
        isIntroOffer: Boolean(v.isIntroOffer),
        isHiddenSku: Boolean(v.isHiddenSku),
        introPeriod: v.introPeriod || null,
        renewPrice: (v.renewByRegion && v.renewByRegion[region.id]) ? v.renewByRegion[region.id] : null
      });
    }
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
    const bundleId = dlInfo.bundleId || `com.app.id${targetAppId}`;
    const skuId = inferStoreKitSku(targetAppId, p.title, p.sku);

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
      bundleId,
      skuId,
      hasNativeScheme: Boolean(dlInfo.scheme),
      purchaseIntentUrl: `itms-services://?action=purchaseIntent&bundleId=${encodeURIComponent(bundleId)}&productIdentifier=${encodeURIComponent(skuId)}`,
      appSchemeUrl: dlInfo.scheme || `itms-apps://itunes.apple.com/${region.id}/app/id${targetAppId}?mt=8`,
      appPaywallWebUrl: dlInfo.webUrl || `https://apps.apple.com/${region.id}/app/id${targetAppId}`,
      appleSubscriptionUrl: `itms-apps://apps.apple.com/account/subscriptions?app-id=${targetAppId}`,
      storeAppUrl: `itms-apps://itunes.apple.com/${region.id}/app/id${targetAppId}?mt=8`,
      isHiddenCompanion: Boolean(p.isHiddenCompanion),
      isUncoveredFromOtherRegion: Boolean(p.isUncoveredFromOtherRegion),
      isIntroOffer: Boolean(p.isIntroOffer),
      isHiddenSku: Boolean(p.isHiddenSku || p.isHiddenCompanion || p.isUncoveredFromOtherRegion),
      introPeriod: p.introPeriod || null,
      renewPrice: p.renewPrice || null
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
        isDeepHidden: false,
        hasIntroOffer: false
      });
    }
    const g = map.get(key);
    g.offers.push(offer);
    if (offer.isHiddenCompanion || offer.isUncoveredFromOtherRegion || offer.isHiddenSku) {
      g.isDeepHidden = true;
    }
    if (offer.isIntroOffer) {
      g.hasIntroOffer = true;
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
