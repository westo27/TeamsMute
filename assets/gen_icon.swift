// Generates the Hushkey app icon (1024x1024 PNG).
// Run: swift assets/gen_icon.swift assets/icon_1024.png
import AppKit

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background: macOS-style rounded square, indigo-violet gradient.
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.2237, yRadius: size * 0.2237)
NSGradient(colors: [
    NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.55, alpha: 1),
])!.draw(in: bgPath, angle: -90)

// Keycap: inner rounded square with a subtle highlight, hinting at a keyboard key.
let capInset: CGFloat = size * 0.10
let capRect = bgRect.insetBy(dx: capInset, dy: capInset)
let capPath = NSBezierPath(roundedRect: capRect, xRadius: size * 0.16, yRadius: size * 0.16)
NSGradient(colors: [
    NSColor(calibratedWhite: 1, alpha: 0.16),
    NSColor(calibratedWhite: 1, alpha: 0.04),
])!.draw(in: capPath, angle: -90)
NSColor(calibratedWhite: 1, alpha: 0.25).setStroke()
capPath.lineWidth = size * 0.008
capPath.stroke()

// Glyph: muted microphone, drawn white.
let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .medium)
if let symbol = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
    tinted.unlockFocus()
    let glyphRect = NSRect(x: (size - symbol.size.width) / 2,
                           y: (size - symbol.size.height) / 2,
                           width: symbol.size.width,
                           height: symbol.size.height)
    tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to render icon")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
