import AppKit
import Foundation

// A simple editable, geometric Gomoku icon. No external artwork or fonts.
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.shouldAntialias = true
func colour(_ hex: Int) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
colour(0x14251F).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))).fill()
colour(0x476B59).setStroke()
let grid = NSBezierPath()
grid.lineWidth = 5
for n in 0..<5 {
    let v = CGFloat(232 + n * 140)
    grid.move(to: NSPoint(x: 176, y: v)); grid.line(to: NSPoint(x: 848, y: v))
    grid.move(to: NSPoint(x: v, y: 176)); grid.line(to: NSPoint(x: v, y: 848))
}
grid.stroke()
for n in 0..<5 {
    let v = CGFloat(232 + n * 140)
    colour(0xA8D5BF).setFill()
    NSBezierPath(ovalIn: NSRect(x: v - 51, y: v - 51, width: 102, height: 102)).fill()
}
for (x, y) in [(372, 232), (512, 372), (652, 512)] {
    let stone = NSBezierPath(ovalIn: NSRect(x: CGFloat(x - 47), y: CGFloat(y - 47), width: 94, height: 94))
    colour(0x0D1813).setFill(); stone.fill()
    colour(0x729682).setStroke(); stone.lineWidth = 3; stone.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let folder = URL(fileURLWithPath: "Gomoku/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("AppIcon.png"))
let contents = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try contents.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try "{\"info\":{\"author\":\"xcode\",\"version\":1}}".write(
    to: folder.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
