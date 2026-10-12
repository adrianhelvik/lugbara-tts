// Draws the app icon: logo A on the brown background, at 1024 x 1024.
// Run: swift assets/make-icon.swift assets/AppIcon-1024.png
import AppKit

let size: CGFloat = 1024
let brown = CGColor(srgbRed: 0x3A/255, green: 0x24/255, blue: 0x17/255, alpha: 1)
let bone = CGColor(srgbRed: 0xF4/255, green: 0xEB/255, blue: 0xDD/255, alpha: 1)
let ochre = CGColor(srgbRed: 0xD9/255, green: 0xA1/255, blue: 0x3B/255, alpha: 1)
let terra = CGColor(srgbRed: 0xC4/255, green: 0x53/255, blue: 0x2D/255, alpha: 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let c = NSGraphicsContext.current!.cgContext

// The rounded square of a macOS app icon, with a soft shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
c.saveGState()
c.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
c.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
c.setFillColor(brown)
c.fillPath()
c.restoreGState()

// The logo is drawn in a 120 x 120 box with y pointing down, mapped onto the middle of the tile.
let scale: CGFloat = 5.4
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 512 + (x - 60) * scale, y: 512 - (y - 62) * scale) }
let width = 11 * scale
c.setLineWidth(width)
c.setLineCap(.round)

c.setStrokeColor(bone)
c.move(to: p(18, 32)); c.addLine(to: p(66, 32))
c.move(to: p(18, 58)); c.addLine(to: p(80, 58))
c.strokePath()

c.setStrokeColor(ochre)
for i in 0...120 {
    let t = CGFloat(i) / 120
    let point = p(18 + 84 * t, 88 + 12 * sin(t * 3 * .pi + .pi))
    i == 0 ? c.move(to: point) : c.addLine(to: point)
}
c.strokePath()

c.setFillColor(terra)
let dot = p(91, 32)
let r = width * 0.95
c.fillEllipse(in: CGRect(x: dot.x - r, y: dot.y - r, width: 2 * r, height: 2 * r))

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
