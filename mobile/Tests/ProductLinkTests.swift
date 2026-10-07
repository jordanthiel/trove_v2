import Foundation
@main struct LinkTests {
 static func main() {
  let cases: [(String,String?)] = [
   ("Archies Arch Support Flip Flops for Men & Women\nhttps://a.co/d/Ab12Cd", "https://a.co/d/Ab12Cd"),
   ("https://www.amazon.com/dp/B0GDWNCV2L?th=1&psc=1", "https://www.amazon.com/dp/B0GDWNCV2L?th=1&psc=1"),
   ("Check this out: https://a.co/d/Ab12Cd.", "https://a.co/d/Ab12Cd"),
   ("[Flip flops](https://www.amazon.com/dp/B012345678)", "https://www.amazon.com/dp/B012345678"),
   ("Archies Arch Support Flip Flops for Men & Women",nil),
   ("",nil), ("javascript:alert(1)",nil), ("https://localhost/item",nil),
   ("amazon.com/dp/B012345678", "http://amazon.com/dp/B012345678")]
  for (input,expected) in cases { precondition(ProductLink.extract(input)==expected,"Failed: \(input) -> \(ProductLink.extract(input) ?? "nil")") }
  print("PASS: 9 product link extraction cases")
 }
}
