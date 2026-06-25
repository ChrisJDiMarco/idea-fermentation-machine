#!/usr/bin/env swift
// Generates the Chrome extension's PNG icons (16/48/128) — a white flask on the
// app's green, matching the in-app "flask" glyph. Run from the project root:
//   swift Scripts/make_extension_icons.swift
import AppKit
import Foundation

_ = NSApplication.shared // ensure AppKit is initialized for offscreen drawing

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("ChromeExtension/icons", isDirectory: true)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let green = NSColor(srgbRed: 0.02, green: 0.62, blue: 0.39, alpha: 1)

func icon(size: Int) -> Data? {
    let s = CGFloat(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.05
    let bgRect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    NSBezierPath(roundedRect: bgRect, xRadius: s * 0.22, yRadius: s * 0.22).fill(with: green)

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }

    let flask = NSBezierPath()
    flask.move(to: point(0.43, 0.80))
    flask.line(to: point(0.43, 0.58))
    flask.line(to: point(0.23, 0.26))
    flask.curve(to: point(0.77, 0.26), controlPoint1: point(0.31, 0.17), controlPoint2: point(0.69, 0.17))
    flask.line(to: point(0.57, 0.58))
    flask.line(to: point(0.57, 0.80))
    flask.close()
    NSColor.white.setFill()
    flask.fill()

    NSBezierPath(roundedRect: NSRect(x: 0.385 * s, y: 0.79 * s, width: 0.23 * s, height: 0.065 * s),
                 xRadius: 0.032 * s, yRadius: 0.032 * s).fill()

    if size >= 48 {
        let liquid = NSBezierPath()
        liquid.move(to: point(0.33, 0.40))
        liquid.line(to: point(0.67, 0.40))
        liquid.lineWidth = max(1, s * 0.028)
        green.setStroke()
        liquid.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

extension NSBezierPath {
    func fill(with color: NSColor) { color.setFill(); fill() }
}

for size in [16, 48, 128] {
    if let data = icon(size: size) {
        let url = outputDir.appendingPathComponent("icon\(size).png")
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent) (\(data.count) bytes)")
    } else {
        print("failed to render icon\(size).png")
    }
}
