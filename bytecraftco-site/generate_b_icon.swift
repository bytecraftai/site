#!/usr/bin/env swift
// Renders the ByteCraftCo "B" icon at the requested size.
// Usage: swift generate_b_icon.swift <size> <output.png>
import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    print("usage: swift generate_b_icon.swift <size> <output.png>")
    exit(1)
}
let size = Int(CommandLine.arguments[1]) ?? 1024
let outputPath = CommandLine.arguments[2]

let coral = NSColor(red: 1.00, green: 0.44, blue: 0.38, alpha: 1.0)
let teal  = NSColor(red: 0.16, green: 0.62, blue: 0.56, alpha: 1.0)

/// HSV-interpolated stops between two colors — much more vibrant than RGB lerp
/// when blending warm/cool colors (RGB mid-tone goes muddy brown).
func hsvStops(from a: NSColor, to b: NSColor, count: Int = 12) -> [NSColor] {
    let aSRGB = a.usingColorSpace(.sRGB) ?? a
    let bSRGB = b.usingColorSpace(.sRGB) ?? b
    var ah: CGFloat = 0, asat: CGFloat = 0, av: CGFloat = 0, aa: CGFloat = 0
    var bh: CGFloat = 0, bsat: CGFloat = 0, bv: CGFloat = 0, ba: CGFloat = 0
    aSRGB.getHue(&ah, saturation: &asat, brightness: &av, alpha: &aa)
    bSRGB.getHue(&bh, saturation: &bsat, brightness: &bv, alpha: &ba)

    // Always go the SHORT way around the hue wheel
    var hueDelta = bh - ah
    if hueDelta > 0.5 { hueDelta -= 1.0 }
    if hueDelta < -0.5 { hueDelta += 1.0 }

    return (0..<count).map { i in
        let f = CGFloat(i) / CGFloat(count - 1)
        var h = ah + hueDelta * f
        if h < 0 { h += 1 }
        if h > 1 { h -= 1 }
        let s = asat + (bsat - asat) * f
        let v = av + (bv - av) * f
        // Goose saturation/brightness in the middle so the blend stays vivid
        let bump = sin(.pi * f) * 0.10
        let s2 = min(1, s + bump)
        let v2 = min(1, v + bump * 0.5)
        let alpha = aa + (ba - aa) * f
        return NSColor(hue: h, saturation: s2, brightness: v2, alpha: alpha)
    }
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { exit(2) }

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { exit(3) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

let s = CGFloat(size)
let bounds = NSRect(x: 0, y: 0, width: s, height: s)
let cornerRadius = s * (10.0 / 44.0)

// Clip + gradient fill
ctx.saveGraphicsState()
NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
// 4-stop gradient — each color dominant in its half so the
// transition zone stays narrow and the corners stay vibrant.
let stops: [NSColor] = [coral, coral, teal, teal]
let locations: [CGFloat] = [0.0, 0.42, 0.58, 1.0]
let gradient = NSGradient(colors: stops, atLocations: locations, colorSpace: .sRGB)!
gradient.draw(in: bounds, angle: -45) // top-left → bottom-right (matches CSS 135deg)
ctx.restoreGraphicsState()

// Draw the B in white SF Pro Rounded Heavy
let fontSize = s * (24.0 / 44.0)
let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
let roundedDesc = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
let font = NSFont(descriptor: roundedDesc, size: fontSize) ?? baseFont

let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
]
let text = NSAttributedString(string: "B", attributes: attrs)
let textSize = text.size()
let yOffset = s * 0.02
let textRect = NSRect(
    x: (s - textSize.width) / 2,
    y: (s - textSize.height) / 2 - yOffset,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    print("✗ Failed to encode PNG"); exit(4)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("✓ Wrote \(size)x\(size) → \(outputPath) (\(png.count) bytes)")
