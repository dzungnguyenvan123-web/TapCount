#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: generate_icon.swift <output-iconset-dir>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let specs: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func renderIcon(pixelSize: Int) -> Data {
    let s = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let nsContext = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsContext
    let ctx = nsContext.cgContext

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // macOS icon padding & squircle rounded rect
    let inset = s * 0.085
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = rect.width * 0.225
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Subtle outer shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.015),
        blur: s * 0.035,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25)
    )
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(red: 0.06, green: 0.52, blue: 0.90, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Gradient fill inside squircle
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.05, green: 0.72, blue: 0.88, alpha: 1.0),
        CGColor(red: 0.11, green: 0.42, blue: 0.94, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )

    // Concentric subtle tap ripple rings
    let center = CGPoint(x: s * 0.5, y: s * 0.5)
    for (radiusFactor, alpha) in [(0.34, 0.14), (0.25, 0.22)] as [(CGFloat, CGFloat)] {
        let r = rect.width * radiusFactor
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
        ctx.setLineWidth(max(1.0, s * 0.018))
        ctx.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    // Crisp white central disc
    let discR = rect.width * 0.18
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    ctx.fillEllipse(in: CGRect(x: center.x - discR, y: center.y - discR, width: discR * 2, height: discR * 2))

    // Bold "+" inside central disc
    let plusHalf = discR * 0.52
    let plusThick = max(1.5, s * 0.048)
    ctx.setStrokeColor(CGColor(red: 0.08, green: 0.47, blue: 0.91, alpha: 1.0))
    ctx.setLineWidth(plusThick)
    ctx.setLineCap(.round)

    ctx.move(to: CGPoint(x: center.x - plusHalf, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + plusHalf, y: center.y))
    ctx.move(to: CGPoint(x: center.x, y: center.y - plusHalf))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y + plusHalf))
    ctx.strokePath()

    // Subtle top sheen
    let sheenRect = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height * 0.55)
    let sheenColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let sheen = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        sheen,
        start: CGPoint(x: sheenRect.midX, y: sheenRect.maxY),
        end: CGPoint(x: sheenRect.midX, y: sheenRect.minY),
        options: []
    )
    ctx.restoreGState()

    // Subtle inner highlight border
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.setLineWidth(max(1.0, s * 0.008))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for spec in specs {
    let data = renderIcon(pixelSize: spec.size)
    try data.write(to: outputDir.appendingPathComponent(spec.name))
}
