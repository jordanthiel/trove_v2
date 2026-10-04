import { extractProduct, publicURL, publicAddress, amazonURL } from './metadata.ts'
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`)
}
Deno.test('Product graph: names, entities, offers, image object and relative image', () => {
 const p=extractProduct(`<script type="application/ld+json">{"@graph":[{"@type":"Organization"},{"@type":"Product","name":"Coffee &amp; tea","description":"<p>Green mug</p>","image":[{"@type":"ImageObject","url":"/images/mug.jpg"}],"offers":{"price":"28.50","priceCurrency":"USD"}}]}</script>`, 'https://shop.example.com/products/mug')
 equal(p,{name:'Coffee & tea',description:'Green mug',price:28.5,currency:'USD',image_url:'https://shop.example.com/images/mug.jpg',link:'https://shop.example.com/products/mug'})
})
Deno.test('Open Graph, reordered attributes, entities, decimal zero and protocol-relative images', () => {
 const p=extractProduct(`<meta content='A &quot;great&quot; gift' property='og:title'><meta content="//cdn.example.com/photo.jpg" property="og:image"><meta property="product:price:amount" content="0"><meta name="description" content="Lovely &amp; useful">`, 'https://shop.example.com/p')
 equal(p.name,'A "great" gift');equal(p.image_url,'https://cdn.example.com/photo.jpg');equal(p.price,0);equal(p.description,'Lovely & useful')
})
Deno.test('Invalid structured data falls back to metadata; malicious image schemes rejected', () => {
 const p=extractProduct(`<script type="application/ld+json">invalid</script><meta property="og:image" content="javascript:alert(1)"><title>Fallback title</title>`,'https://shop.example.com/p')
 equal(p.name,'Fallback title');equal(p.image_url,null)
})
Deno.test('Non-USD currency is preserved and no price is invented', () => {
 const p=extractProduct(`<script type="application/ld+json">[{"@type":["Thing","Product"],"name":"Lamp","offers":[{"price":"45.99","priceCurrency":"EUR"}]}]</script>`,'https://shop.example.com/p')
 equal(p.price,45.99);equal(p.currency,'EUR');equal(extractProduct('<title>No price</title>','https://shop.example.com/p').price,null)
})
Deno.test('Public URL validation rejects internal hosts, credentials, ports, and encoded IPs', () => {
 for (const url of ['http://localhost/p','http://127.0.0.1/p','http://2130706433/p','http://0x7f000001/p','http://[::1]/p','https://shop.local/p','ftp://example.com/p','https://user:pass@example.com/p','https://example.com:8080/p']) {
  let rejected=false;try{publicURL(url)}catch{rejected=true}equal(rejected,true)
 }
 equal(publicURL('https://shop.example.com/p#section').href,'https://shop.example.com/p')
})
Deno.test('Public IP validation blocks private, metadata, mapped and reserved ranges', () => {
 for (const ip of ['127.0.0.1','10.1.1.1','172.16.0.2','192.168.1.1','169.254.169.254','100.100.100.200','198.18.0.1','203.0.113.1','::1','fc00::1','fe80::1','::ffff:127.0.0.1','2001:db8::1','2002:7f00:1::']) equal(publicAddress(ip),false)
 equal(publicAddress('8.8.8.8'),true);equal(publicAddress('2606:4700:4700::1111'),true)
})

Deno.test('Amazon mobile: exact title, main photo and buy-box price instead of list price or recommendations', () => {
 const p=extractProduct(`<title>Amazon.com | Luggage</title><h1><span id="title">LIGHT FLIGHT Expandable 20&#34; Carry On</span></h1><div id="pqv-feature-bullets"><ul><li>Expandable &amp; lightweight</li></ul></div><img id="main-image" data-a-hires="https://m.media-amazon.com/images/I/purple.jpg"><span class="a-price a-text-price"><span class="a-offscreen">$99.99</span></span><div id="corePrice_feature_div"><span class="priceToPay"><span class="a-offscreen">$52.99</span></span></div><div>Recommended: $15.00</div>`,'https://www.amazon.com/dp/B0GDWNCV2L?th=1')
 equal(p.name,'LIGHT FLIGHT Expandable 20" Carry On');equal(p.price,52.99);equal(p.currency,'USD');equal(p.description,'Expandable & lightweight');equal(p.image_url,'https://m.media-amazon.com/images/I/purple.jpg')
})
Deno.test('Amazon desktop: high resolution dynamic image and thousands in current price', () => {
 const p=extractProduct(`<span id="productTitle">Laptop</span><img id="landingImage" data-a-dynamic-image='{&quot;https://m.media-amazon.com/small.jpg&quot;:[100,100],&quot;https://m.media-amazon.com/large.jpg&quot;:[1000,1000]}'><div id="corePriceDisplay_desktop_feature_div"><span class="a-price a-text-price"><span class="a-offscreen">$1,999.00</span></span><span class="a-price"><span class="a-offscreen">$1,249.99</span></span></div>`,'https://www.amazon.com/dp/B012345678')
 equal(p.price,1249.99);equal(p.image_url,'https://m.media-amazon.com/large.jpg')
})
Deno.test('Amazon challenge pages cannot become gift items', () => {
 for(const html of ['<title>Amazon.com</title><form action="/errors_page/validateCaptcha"></form>','<title>Amazon.com</title><h4>Continue shopping</h4>']) {
  let rejected=false;try{extractProduct(html,'https://www.amazon.com/dp/B012345678')}catch{rejected=true}equal(rejected,true)
 }
})
Deno.test('Amazon tracking links canonicalize while retaining variant; short links remain resolvable', () => {
 equal(amazonURL('https://www.amazon.com/LIGHT-FLIGHT/dp/B0GDWNCV2L/?ref_=home&th=1&psc=1').href,'https://www.amazon.com/dp/B0GDWNCV2L?th=1&psc=1')
 equal(amazonURL('https://www.amazon.co.uk/gp/aw/d/B012345678/ref=share').href,'https://www.amazon.co.uk/dp/B012345678')
 equal(amazonURL('https://a.co/d/AbCd').href,'https://a.co/d/AbCd')
 equal(amazonURL('https://shop.example.com/dp/B012345678?ref=x').href,'https://shop.example.com/dp/B012345678?ref=x')
})
