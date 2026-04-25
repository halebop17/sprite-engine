#!/usr/bin/env swift
// Generates all required macOS app icon PNGs for Assets.xcassets/AppIcon.appiconset/
// Run from project root: swift scripts/make_icon.swift

import Cocoa
import CoreGraphics

let outputDir = "SpriteEngine/Resources/Assets.xcassets/AppIcon.appiconset"

// Icon sizes required for macOS
let sizes: [(pt: Int, scale: Int)] = [
    (16,  1), (16,  2),
    (32,  1), (32,  2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

func drawIcon(size: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    let s = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Background: dark navy rounded rect
    let radius = s * 0.22
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    ctx.addPath(bg.cgPath)
    ctx.setFillColor(CGColor(red: 0.059, green: 0.059, blue: 0.11, alpha: 1))
    ctx.fillPath()

    // Accent gradient overlay
    let gradient = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.91, green: 0.0,  blue: 0.11, alpha: 0.9),
            CGColor(red: 0.91, green: 0.0,  blue: 0.11, alpha: 0.0),
        ] as CFArray,
        locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(bg.cgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
        start: CGPoint(x: 0, y: s),
        end:   CGPoint(x: s, y: 0),
        options: [])
    ctx.restoreGState()

    // Inner glow circle
    let glowR = s * 0.34
    let glowRect = CGRect(
        x: s / 2 - glowR, y: s / 2 - glowR,
        width: glowR * 2, height: glowR * 2)
    let glow = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.91, green: 0.0, blue: 0.11, alpha: 0.3),
            CGColor(red: 0.91, green: 0.0, blue: 0.11, alpha: 0.0),
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawRadialGradient(glow,
        startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
        endCenter:   CGPoint(x: s / 2, y: s / 2), endRadius: glowR,
        options: [])

    // Draw joystick symbol via simple geometric shapes (stands in for SF Symbol)
    let pad   = s * 0.28
    let inner = s - pad * 2
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))

    // Base rectangle (arcade panel)
    let baseH = inner * 0.28
    let baseRect = CGRect(x: pad, y: pad + inner * 0.1, width: inner, height: baseH)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: baseH * 0.25, yRadius: baseH * 0.25)
    ctx.addPath(basePath.cgPath)
    ctx.fillPath()

    // Stick shaft
    let shaftW = inner * 0.095
    let shaftH = inner * 0.38
    let shaftRect = CGRect(
        x: s / 2 - shaftW / 2,
        y: pad + inner * 0.1 + baseH,
        width: shaftW, height: shaftH)
    let shaftPath = NSBezierPath(roundedRect: shaftRect, xRadius: shaftW / 2, yRadius: shaftW / 2)
    ctx.addPath(shaftPath.cgPath)
    ctx.fillPath()

    // Ball top
    let ballR = inner * 0.115
    ctx.addEllipse(in: CGRect(
        x: s / 2 - ballR,
        y: pad + inner * 0.1 + baseH + shaftH - ballR * 0.3,
        width: ballR * 2, height: ballR * 2))
    ctx.setFillColor(CGColor(red: 0.91, green: 0.0, blue: 0.11, alpha: 1))
    ctx.fillPath()

    // Two buttons on the base
    let btnR    = baseH * 0.28
    let btnY    = pad + inner * 0.1 + baseH / 2 - btnR
    let btn1X   = pad + inner * 0.62
    let btn2X   = pad + inner * 0.79
    ctx.setFillColor(CGColor(red: 0.91, green: 0.0, blue: 0.11, alpha: 1))
    ctx.addEllipse(in: CGRect(x: btn1X, y: btnY, width: btnR * 2, height: btnR * 2))
    ctx.fillPath()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
    ctx.addEllipse(in: CGRect(x: btn2X, y: btnY, width: btnR * 2, height: btnR * 2))
    ctx.fillPath()

    return ctx.makeImage()
}

// NSBezierPath → CGPath bridge for pre-Sonoma
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &points) {
            case .moveTo:       path.move(to: points[0])
            case .lineTo:       path.addLine(to: points[0])
            case .curveTo:      path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:    path.closeSubpath()
            @unknown default:   break
            }
        }
        return path
    }
}

// Write PNGs
let fm = FileManager.default
for (pt, scale) in sizes {
    let px = pt * scale
    guard let img = drawIcon(size: px) else { continue }
    let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@\(scale)x.png"
    let path = "\(outputDir)/\(name)"
    let nsImg = NSImage(cgImage: img, size: NSSize(width: pt, height: pt))
    guard let tiff = nsImg.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:])
    else { print("Failed \(name)"); continue }
    fm.createFile(atPath: path, contents: png)
    print("✓ \(name)  (\(px)×\(px)px)")
}
print("Done.")
