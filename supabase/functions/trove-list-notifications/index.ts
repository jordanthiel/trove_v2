type Batch = {
  id: string; lease_id: string; token: string; environment: string
  list_id: string; list_name: string; item_count: number
}
const env = (name: string) => Deno.env.get(name) ?? ''
const encode = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '')
const text = new TextEncoder()
let cached: { value: string; created: number } | undefined
async function providerToken() {
  const now = Math.floor(Date.now() / 1000)
  if (cached && now - cached.created < 45 * 60) return cached.value
  const keyID = env('TROVE_APNS_KEY_ID'), teamID = env('TROVE_APNS_TEAM_ID')
  const pem = env('TROVE_APNS_PRIVATE_KEY').replace(/\\n/g, '\n')
  if (!keyID || !teamID || !pem) throw new Error('APNs not configured')
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----|\s/g, '')), c => c.charCodeAt(0))
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const unsigned = [
    encode(text.encode(JSON.stringify({ alg: 'ES256', kid: keyID }))),
    encode(text.encode(JSON.stringify({ iss: teamID, iat: now }))),
  ].join('.')
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, text.encode(unsigned))
  cached = { value: unsigned + '.' + encode(new Uint8Array(signature)), created: now }
  return cached.value
}
async function rpc(name: string, body: unknown) {
  const service = env('SUPABASE_SERVICE_ROLE_KEY')
  const response = await fetch(env('SUPABASE_URL') + '/rest/v1/rpc/' + name, {
    method: 'POST', headers: { apikey: service, Authorization: 'Bearer ' + service, 'Content-Type': 'application/json' },
    body: JSON.stringify(body), signal: AbortSignal.timeout(10000),
  })
  if (!response.ok) throw new Error('Queue request failed: ' + response.status)
  return response
}
async function deliver(batch: Batch, jwt: string) {
  const host = batch.environment === 'development' ? 'api.sandbox.push.apple.com' : 'api.push.apple.com'
  let result = 'retry'
  try {
    const response = await fetch('https://' + host + '/3/device/' + batch.token, {
      method: 'POST',
      headers: {
        Authorization: 'bearer ' + jwt, 'apns-topic': 'com.jordanthiel.trove-rn',
        'apns-push-type': 'alert', 'apns-priority': '10', 'apns-collapse-id': batch.id, 'apns-id': batch.id,
        'apns-expiration': String(Math.floor(Date.now() / 1000) + 3600),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ aps: {
        alert: { title: batch.list_name, body: batch.item_count === 1 ? '1 new wish was added.' : batch.item_count + ' new wishes were added.' },
        sound: 'default',
      }, list_id: batch.list_id }),
      signal: AbortSignal.timeout(6000),
    })
    if (response.ok) result = 'sent'
    else {
      const reason = (await response.json().catch(() => ({}))).reason
      if (reason === 'Unregistered' || reason === 'BadDeviceToken') result = 'invalid_token'
      else console.warn('Trove APNs response', response.status, reason)
    }
  } catch { console.warn('Trove APNs connection failed') }
  await rpc('trove_finish_list_notification', { p_id: batch.id, p_lease: batch.lease_id, p_result: result, p_token: batch.token })
  return result
}
Deno.serve(async request => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  const key = env('TROVE_PUSH_WORKER_KEY')
  if (!key || request.headers.get('x-trove-worker-key') !== key) return new Response('Unauthorized', { status: 401 })
  try {
    const jwt = await providerToken()
    const batches: Batch[] = await (await rpc('trove_take_list_notifications', {})).json()
    let sent = 0
    for (let i = 0; i < batches.length; i += 10) {
      const outcomes = await Promise.allSettled(batches.slice(i, i + 10).map(batch => deliver(batch, jwt)))
      sent += outcomes.filter(outcome => outcome.status === 'fulfilled' && outcome.value === 'sent').length
    }
    return Response.json({ attempted: batches.length, sent })
  } catch { return new Response('Notification worker unavailable', { status: 503 }) }
})
