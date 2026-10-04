import { load } from 'npm:cheerio@1.0.0/slim'

export type ProductPreview = {
  name: string | null
  description: string | null
  price: number | null
  currency: string | null
  image_url: string | null
  link: string
}

export function publicURL(value: string, base?: string): URL {
  const url = new URL(value, base)
  const host = url.hostname.toLowerCase().replace(/\.$/, '')
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password ||
      url.port || !host.includes('.') || host.includes(':') ||
      /(^|\.)(localhost|local|internal|test|invalid)$/.test(host) ||
      /^\d+(\.\d+){3}$/.test(host) || url.href.length > 4096) {
    throw new Error('Please use a public product link beginning with https://.')
  }
  url.hostname = host
  url.hash = ''
  return url
}

export function publicAddress(ip: string): boolean {
  if (ip.includes(':')) {
    // Only native global-unicast IPv6. Reject mapped IPv4, local, multicast,
    // documentation, and transition ranges that can tunnel to private IPv4.
    const lower = ip.toLowerCase()
    return /^[23][0-9a-f]{0,3}:/.test(lower) &&
      !/^(2001:(db8|0|2|10|20):|2002:)/.test(lower)
  }
  const octets = ip.split('.').map(Number)
  if (octets.length !== 4 || octets.some(n => !Number.isInteger(n) || n < 0 || n > 255)) return false
  const [a,b,c] = octets
  return !(a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) || (a === 192 && (b === 168 || b === 0 || b === 2)) ||
    (a === 198 && (b === 18 || b === 19 || (b === 51 && c === 100))) ||
    (a === 203 && b === 0 && c === 113))
}

export function amazonURL(value: string): URL {
  const url = publicURL(value)
  if (/(^|\.)amazon\.(com|ca|co\.uk|com\.au|de|fr|it|es|co\.jp|in|com\.mx)$/.test(url.hostname)) {
    const asin = /\/(?:dp|gp\/product|gp\/aw\/d)\/([A-Z0-9]{10})(?:[/?]|$)/i.exec(url.pathname)?.[1]
    if (asin) {
      url.pathname = `/dp/${asin.toUpperCase()}`
      const variant = url.searchParams.get('th'), quantity = url.searchParams.get('psc')
      url.search = ''
      if (variant) url.searchParams.set('th', variant)
      if (quantity) url.searchParams.set('psc', quantity)
    }
  }
  return url
}

export function extractProduct(html: string, pageURL: string): ProductPreview {
  const $ = load(html)
  const amazon = /(^|\.)amazon\.(com|ca|co\.uk|com\.au|de|fr|it|es|co\.jp|in|com\.mx)$/.test(new URL(pageURL).hostname)
  if (amazon && ($('form[action*="validateCaptcha"]').length || /robot check|captcha|access denied/i.test($('title').text()))) {
    throw new Error('Amazon needs a browser check before sharing this product. Try again, or enter the details manually.')
  }
  const text = (value: unknown, limit = 2000): string | null => {
    if (typeof value !== 'string') return null
    const plain = load(value).text().replace(/\s+/g, ' ').trim()
    return plain ? plain.slice(0, limit) : null
  }
  const metas = new Map<string,string>()
  $('meta').each((_, tag) => {
    const key = ($(tag).attr('property') ?? $(tag).attr('name') ?? $(tag).attr('itemprop') ?? '').toLowerCase()
    const content = $(tag).attr('content')
    if (key && content && !metas.has(key)) metas.set(key, content)
  })
  const meta = (...keys: string[]) => keys.map(key => metas.get(key)).find(Boolean) ?? null
  const products: Record<string,unknown>[] = []
  let visited = 0
  function walk(node: unknown, depth = 0) {
    if (depth > 15 || ++visited > 5000 || !node || typeof node !== 'object') return
    if (Array.isArray(node)) { node.forEach(value => walk(value, depth+1)); return }
    const obj = node as Record<string,unknown>
    const types = Array.isArray(obj['@type']) ? obj['@type'] : [obj['@type']]
    if (types.some(t => typeof t === 'string' && /(^|[\/#])Product$/.test(t))) products.push(obj)
    Object.values(obj).forEach(value => walk(value, depth+1))
  }
  $('script[type="application/ld+json"]').each((_, script) => {
    try { walk(JSON.parse($(script).text())) } catch { /* Other page metadata can still work. */ }
  })
  // The primary page product usually precedes related products in the graph.
  const product = products[0] ?? {}
  const rawOffers = product.offers
  const offer = (Array.isArray(rawOffers) ? rawOffers[0] : rawOffers) as Record<string,unknown> | undefined
  const specification = offer?.priceSpecification as Record<string,unknown> | undefined
  const amazonPriceText = amazon ? $('.priceToPay .a-offscreen, #corePriceDisplay_desktop_feature_div .a-price:not(.a-text-price) .a-offscreen, #corePrice_feature_div .a-price:not(.a-text-price) .a-offscreen, #priceblock_ourprice, #priceblock_dealprice').first().text().trim() : ''
  // Read the buy-box price, never a crossed-out list price or a recommended product.
  const amazonPrice = /^\s*(?:US\$|\$|£|€|₹|CDN\$|CA\$)?\s*([\d,]+(?:\.\d{1,2})?)\s*$/.exec(amazonPriceText)?.[1]?.replaceAll(',', '')
  const rawPrice = amazonPrice ?? offer?.price ?? offer?.lowPrice ?? specification?.price ?? meta('product:price:amount','og:price:amount','price')
  const number = typeof rawPrice === 'number' ? rawPrice : typeof rawPrice === 'string' && /^\d+([.,]\d{1,2})?$/.test(rawPrice.trim()) ? Number(rawPrice.replace(',', '.')) : NaN
  const currency = (amazonPrice ? (amazonPriceText.includes('£') ? 'GBP' : amazonPriceText.includes('€') ? 'EUR' : amazonPriceText.includes('₹') ? 'INR' : /CDN|CA/.test(amazonPriceText) || new URL(pageURL).hostname.endsWith('.ca') ? 'CAD' : new URL(pageURL).hostname.endsWith('.com') ? 'USD' : null) : null) ?? text(offer?.priceCurrency ?? specification?.priceCurrency ?? meta('product:price:currency','og:price:currency','pricecurrency'), 3)?.toUpperCase() ?? null
  function image(value: unknown): string | null {
    if (Array.isArray(value)) { for (const v of value) { const found = image(v); if (found) return found } return null }
    if (value && typeof value === 'object') { const obj = value as Record<string,unknown>; return image(obj.contentUrl ?? obj.url) }
    if (typeof value !== 'string' || !value.trim()) return null
    try {
      const url = publicURL(value.trim(), pageURL)
      // ATS requires secure remote images on iOS.
      if (url.protocol === 'http:') url.protocol = 'https:'
      return url.href
    } catch { return null }
  }
  const mainImage = amazon ? $('#landingImage, #imgBlkFront, #main-image').first() : null
  let dynamicImage: unknown = null
  try { const entries = Object.entries(JSON.parse(mainImage?.attr('data-a-dynamic-image') ?? '{}')) as [string,number[]][]; entries.sort((a,b) => (b[1]?.[0] ?? 0)*(b[1]?.[1] ?? 0) - (a[1]?.[0] ?? 0)*(a[1]?.[1] ?? 0)); dynamicImage = entries[0]?.[0] } catch { /* Use the main image attributes. */ }
  const amazonName = amazon ? text($('#productTitle, h1 #title').first().text(),200) : null
  const amazonDescription = amazon ? text($('#feature-bullets li, #pqv-feature-bullets li').map((_,node) => $(node).text()).get().join(' ')) : null
  if (amazon && !amazonName && /^amazon(?:\.[a-z.]+)?$/i.test($('title').text().trim())) throw new Error('Amazon did not share the product details. Try again, or enter them manually.')
  return {
    name: amazonName ?? (text(product.name ?? meta('og:title','twitter:title') ?? $('h1').first().text() ?? $('title').text(), 200) || text($('title').text(),200)),
    description: amazonDescription ?? text(product.description ?? meta('og:description','description','twitter:description')),
    price: Number.isFinite(number) && number >= 0 && number < 100000000 ? number : null,
    currency,
    image_url: image(mainImage?.attr('data-a-hires')) ?? image(mainImage?.attr('data-old-hires')) ?? image(dynamicImage) ?? image(mainImage?.attr('src')) ?? image(product.image) ?? image(meta('og:image:secure_url','og:image','twitter:image','twitter:image:src')) ?? image($('[itemprop="image"]').first().attr('src')),
    link: pageURL,
  }
}
