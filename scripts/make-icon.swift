// Draws a placeholder app icon: gradient square with a bold "E".
// Usage: swift scripts/make-icon.swift Resources/AppIcon.png
import AppKit
import ImageIO

let out = CommandLine.arguments[1]
let size = 1024
let side = CGFloat(size)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

let colors = [
    CGColor(red: 0.13, green: 0.47, blue: 0.96, alpha: 1),
    CGColor(red: 0.48, green: 0.18, blue: 0.86, alpha: 1),
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side), end: CGPoint(x: side, y: 0), options: [])

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let text = "E" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 700, weight: .heavy),
    .foregroundColor: NSColor.white,
]
let textSize = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2 - 30),
          withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(out)") }
print("wrote \(out)")
