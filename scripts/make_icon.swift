#!/usr/bin/env swift
// Generates the SayIt app icon — citron waveform on warm ink, Big Sur-style
// rounded square — into Sources/SayIt/Resources/AppIcon.icns. Run from the
// repo root:
//   swift scripts/make_icon.swift

import AppKit

func drawIcon(px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px)
    // Apple's icon grid: ~9.8% margin, ~18.1% corner radius.
    let margin = s * 0.098
    let squareRect = NSRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let square = NSBezierPath(roundedRect: squareRect, xRadius: s * 0.181, yRadius: s * 0.181)

    let inkTop = NSColor(calibratedRed: 0.105, green: 0.105, blue: 0.118, alpha: 1)
    let inkBottom = NSColor(calibratedRed: 0.051, green: 0.051, blue: 0.059, alpha: 1)
    NSGradient(starting: inkTop, ending: inkBottom)!.draw(in: square, angle: -90)

    // Hairline inner edge for definition against dark docks.
    NSColor(calibratedWhite: 1, alpha: 0.07).setStroke()
    square.lineWidth = max(1, s * 0.004)
    square.stroke()

    // The wave mark: five citron capsules.
    let citron = NSColor(calibratedRed: 0.816, green: 0.945, blue: 0.247, alpha: 1)
    let heights: [CGFloat] = [0.28, 0.52, 0.82, 0.52, 0.28]
    let barWidth = s * 0.062
    let gap = s * 0.055
    let totalWidth = barWidth * CGFloat(heights.count) + gap * CGFloat(heights.count - 1)
    var x = (s - totalWidth) / 2
    for h in heights {
        let barHeight = squareRect.height * h * 0.60
        let barRect = NSRect(x: x, y: (s - barHeight) / 2, width: barWidth, height: barHeight)
        citron.setFill()
        NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        x += barWidth + gap
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconsetURL = URL(fileURLWithPath: "scripts/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let entries: [(size: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2),
]
for entry in entries {
    let px = entry.size * entry.scale
    let rep = drawIcon(px: px)
    let suffix = entry.scale == 2 ? "@2x" : ""
    let name = "icon_\(entry.size)x\(entry.size)\(suffix).png"
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: iconsetURL.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", "Sources/SayIt/Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetURL)
print(process.terminationStatus == 0 ? "wrote Sources/SayIt/Resources/AppIcon.icns" : "iconutil failed")
