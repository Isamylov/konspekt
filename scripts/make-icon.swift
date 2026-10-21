// Renders the app icon. Run:
//   swift scripts/make-icon.swift /tmp/AppIcon.iconset && iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func linear(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [])
}

// Drawn on a 1024 grid with a top-left origin.
func draw(_ ctx: CGContext) {
    // Background squircle with drop shadow.
    let bg = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                    cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: rgb(0x000000, 0.35))
    ctx.addPath(bg)
    ctx.setFillColor(rgb(0x4CCB74))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bg)
    ctx.clip()
    linear(ctx, [rgb(0x9DF0B4), rgb(0x3DBE67)], from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))
    ctx.restoreGState()

    // Speech bubble with a tail at the bottom left.
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: 236, y: 540))
    tail.addLine(to: CGPoint(x: 236, y: 770))
    tail.addQuadCurve(to: CGPoint(x: 420, y: 660), control: CGPoint(x: 300, y: 690))
    tail.closeSubpath()
    let bubble = CGPath(roundedRect: CGRect(x: 200, y: 318, width: 624, height: 352),
                        cornerWidth: 176, cornerHeight: 176, transform: nil).union(tail)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0x0B3D1C, 0.45))
    ctx.addPath(bubble)
    ctx.setFillColor(rgb(0x17191B))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bubble)
    ctx.clip()
    linear(ctx, [rgb(0x2C3033), rgb(0x111214)], from: CGPoint(x: 512, y: 318), to: CGPoint(x: 512, y: 770))
    ctx.restoreGState()

    // Camera lens.
    let c = CGPoint(x: 380, y: 494)
    func circle(_ r: CGFloat, _ color: CGColor, at p: CGPoint = c) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    }
    circle(122, rgb(0xF4F6F5))
    circle(96, rgb(0x0E0F10))
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - 70, y: c.y - 70, width: 140, height: 140))
    ctx.clip()
    let rg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [rgb(0x3A4A60), rgb(0x0E0F10)] as CFArray, locations: nil)!
    ctx.drawRadialGradient(rg, startCenter: CGPoint(x: c.x - 20, y: c.y - 20), startRadius: 0,
                           endCenter: c, endRadius: 70, options: [])
    ctx.restoreGState()
    circle(20, rgb(0xFFFFFF, 0.75), at: CGPoint(x: c.x - 34, y: c.y - 36))
    circle(8, rgb(0xFFFFFF, 0.5), at: CGPoint(x: c.x + 30, y: c.y + 28))

    // Notes: three lines instead of the recording dot.
    ctx.setFillColor(rgb(0x6FE290))
    for (y, w) in [(410.0, 200.0), (478.0, 200.0), (546.0, 128.0)] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: 560, y: y, width: w, height: 30),
                           cornerWidth: 15, cornerHeight: 15, transform: nil))
        ctx.fillPath()
    }
}

func png(size: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(size) / 1024
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: s, y: -s)
    draw(ctx)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    png(size: base, to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    png(size: base * 2, to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
