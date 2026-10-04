import { extractProduct, publicAddress, publicURL, amazonURL } from './metadata.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
})

export async function fetchProduct(link: string) {
  let url = amazonURL(link)
  const signal = AbortSignal.timeout(15000)
  for (let hop = 0; hop < 5; hop++) {
    const records = await Promise.allSettled([
      Deno.resolveDns(url.hostname, 'A'), Deno.resolveDns(url.hostname, 'AAAA'),
    ])
    const ips = records.flatMap(result => result.status === 'fulfilled' ? result.value : [])
    if (!ips.length || ips.some(ip => !publicAddress(ip))) throw new Error('This product link is not accessible.')
    const response = await fetch(url, {
      redirect: 'manual', signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; TroveProductPreview/1.0)',
        'Accept': 'text/html,application/xhtml+xml', 'Accept-Language': 'en-US,en;q=0.9',
      },
    })
    if ([301,302,303,307,308].includes(response.status)) {
      const location = response.headers.get('location')
      await response.body?.cancel()
      if (!location) throw new Error('The store returned an invalid redirect.')
      url = publicURL(location, url.href)
      continue
    }
    if (!response.ok) { await response.body?.cancel(); throw new Error('This store could not share its product details. You can add them manually.') }
    const contentType = response.headers.get('content-type') ?? ''
    if (!/text\/html|application\/xhtml\+xml/i.test(contentType)) { await response.body?.cancel(); throw new Error('Please use a product page link.') }
    const maxBytes = 6_000_000
    if (Number(response.headers.get('content-length') ?? 0) > maxBytes) { await response.body?.cancel(); throw new Error('This page is too large to preview. You can add the item manually.') }
    const reader = response.body?.getReader()
    if (!reader) throw new Error('This page has no product details.')
    const chunks: Uint8Array[] = []; let bytes = 0
    try {
      while (true) {
        const {value,done} = await reader.read()
        if (done) break
        bytes += value.length
        if (bytes > maxBytes) throw new Error('This page is too large to preview. You can add the item manually.')
        chunks.push(value)
      }
    } finally { await reader.cancel().catch(() => {}); reader.releaseLock() }
    const body = new Uint8Array(bytes); let offset = 0
    for (const chunk of chunks) { body.set(chunk,offset); offset += chunk.length }
    const charset = /charset=["']?([\w-]+)/i.exec(contentType)?.[1] ?? 'utf-8'
    let html: string
    try { html = new TextDecoder(charset).decode(body) } catch { html = new TextDecoder().decode(body) }
    if (/captcha|robot check|verify you are human|access denied/i.test(/<title[^>]*>([\s\S]*?)<\/title>/i.exec(html)?.[1] ?? '')) throw new Error('This store blocked the lookup. You can add the details manually.')
    const product = extractProduct(html,url.href)
    if (!product.name || (/^(products|shop|home|page not found|404.*)$/i.test(product.name) && !product.image_url && product.price === null)) throw new Error('No product details were found. You can add them manually.')
    return product
  }
  throw new Error('This link redirected too many times. Try the full product page link.')
}

export async function handler(req: Request) {
  if (req.method === 'OPTIONS') return new Response('ok', {headers:cors})
  if (req.method !== 'POST') return json({error:'Use POST'},405)
  try {
    const authorization = req.headers.get('Authorization')
    const auth = authorization ? await fetch(`${Deno.env.get('SUPABASE_URL')}/auth/v1/user`, {
      headers:{Authorization:authorization,apikey:Deno.env.get('SUPABASE_ANON_KEY')!}, signal:AbortSignal.timeout(5000),
    }) : null
    if (!auth?.ok) return json({error:'Please sign in to import a product.'},401)
    // Only the product link is sent to the store, never the user's auth token.
    if (Number(req.headers.get('content-length') ?? 0) > 7_000_000) return json({error:'Request too large'},413)
    const body = await req.json()
    if (typeof body.link !== 'string' || body.link.length > 4096) return json({error:'Enter a valid product link.'},400)
    if (typeof body.html === 'string') {
      if (new TextEncoder().encode(body.html).length > 6_000_000) return json({error:'This page is too large to preview.'},413)
      const product = extractProduct(body.html,publicURL(body.link).href)
      if (!product.name || /captcha|robot check|access denied|verify you are human/i.test(product.name)) return json({error:'The store blocked this lookup. Enter the details manually.'},422)
      return json({product})
    }
    return json({product:await fetchProduct(body.link)})
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unable to load product details.'
    return json({error: /timeout|abort|dns|network|fetch|connection|invalid url/i.test(message) ? 'The store could not be reached. Try again, or enter the details manually.' : message},422)
  }
}
