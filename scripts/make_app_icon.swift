// Draws the "Haldi & Masala" app icon (a steaming katori of dal on terracotta) in the three
// iOS appearances and writes 1024×1024 PNGs into the AppIcon set.
//
// Usage (from the repo root): swift scripts/make_app_icon.swift
// Needs only CoreGraphics and ImageIO, so it runs offline with the Xcode toolchain.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let output = URL(fileURLWithPath: "KyaBnaye/KyaBnaye/Assets.xcassets/AppIcon.appiconset")

struct RGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(_ hex: UInt32) {
        red = CGFloat((hex >> 16) & 0xFF) / 255
        green = CGFloat((hex >> 8) & 0xFF) / 255
        blue = CGFloat(hex & 0xFF) / 255
    }

    func cg(_ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// Luminance-preserving grey, for the tinted appearance.
    var grey: RGB {
        let value = UInt32((0.2126 * red + 0.7152 * green + 0.0722 * blue) * 255)
        return RGB(value << 16 | value << 8 | value)
    }
}

/// The colours one appearance is drawn with; `nil` background leaves it transparent.
struct Palette {
    let backgroundTop: RGB?
    let backgroundBottom: RGB?
    let bowl: RGB
    let bowlShade: RGB
    let dal: RGB
    let dalRim: RGB
    let tadka: RGB
    let steam: RGB
    let leaf: RGB
}

let terracotta = RGB(0xA8_431C)
let terracottaDeep = RGB(0x7E_2E10)
let saffron = RGB(0xF2_A541)
let saffronDeep = RGB(0xD9_8A2B)
let cream = RGB(0xFB_F5EC)
let creamShade = RGB(0xE9_DCC8)
let chilli = RGB(0x8C_2A0E)
let curryLeaf = RGB(0x4E_7A2E)

let light = Palette(
    backgroundTop: RGB(0xB8_4E22), backgroundBottom: terracottaDeep, bowl: cream,
    bowlShade: creamShade, dal: saffron, dalRim: saffronDeep, tadka: chilli, steam: cream,
    leaf: curryLeaf)
let dark = Palette(
    backgroundTop: nil, backgroundBottom: nil, bowl: terracotta, bowlShade: terracottaDeep,
    dal: saffron, dalRim: saffronDeep, tadka: chilli, steam: saffron, leaf: curryLeaf)
let tinted = Palette(
    backgroundTop: RGB(0x00_0000), backgroundBottom: RGB(0x00_0000), bowl: cream.grey,
    bowlShade: creamShade.grey, dal: RGB(0xFF_FFFF), dalRim: saffronDeep.grey,
    tadka: RGB(0x55_5555), steam: cream.grey, leaf: RGB(0x80_8080))

func draw(_ palette: Palette, in context: CGContext) {
    let size = CGFloat(side)
    // Core Graphics has y up; every shape below is laid out top-down, so flip once.
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    if let top = palette.backgroundTop, let bottom = palette.backgroundBottom,
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [top.cg(), bottom.cg()] as CFArray, locations: [0, 1])
    {
        context.drawLinearGradient(
            gradient, start: CGPoint(x: size / 2, y: 0), end: CGPoint(x: size / 2, y: size),
            options: [])
    }

    // Steam: three soft S-curves rising from the dal.
    context.setLineCap(.round)
    context.setLineWidth(38)
    context.setStrokeColor(palette.steam.cg(0.9))
    for (index, x) in [382.0, 512.0, 642.0].enumerated() {
        let lift: CGFloat = index == 1 ? 40 : 0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 470 - lift))
        path.addCurve(
            to: CGPoint(x: x, y: 250 - lift), control1: CGPoint(x: x - 60, y: 400 - lift),
            control2: CGPoint(x: x + 60, y: 330 - lift))
        context.addPath(path)
        context.strokePath()
    }

    // The katori: a wide bowl whose rim is an ellipse, body a half-ellipse, on a small foot.
    let rim = CGRect(x: 196, y: 500, width: 632, height: 150)
    let body = CGMutablePath()
    body.move(to: CGPoint(x: rim.minX, y: rim.midY))
    body.addCurve(
        to: CGPoint(x: 512, y: 830), control1: CGPoint(x: rim.minX + 10, y: 740),
        control2: CGPoint(x: 360, y: 830))
    body.addCurve(
        to: CGPoint(x: rim.maxX, y: rim.midY), control1: CGPoint(x: 664, y: 830),
        control2: CGPoint(x: rim.maxX - 10, y: 740))
    body.closeSubpath()
    context.setFillColor(palette.bowlShade.cg())
    context.addPath(CGPath(roundedRect: CGRect(x: 402, y: 812, width: 220, height: 44),
        cornerWidth: 22, cornerHeight: 22, transform: nil))
    context.fillPath()
    context.setFillColor(palette.bowl.cg())
    context.addPath(body)
    context.fillPath()
    context.setFillColor(palette.bowlShade.cg())
    context.fillEllipse(in: rim)

    // Dal filling the rim, with a darker lip and a few tadka seeds.
    context.setFillColor(palette.dalRim.cg())
    context.fillEllipse(in: rim.insetBy(dx: 26, dy: 14))
    context.setFillColor(palette.dal.cg())
    context.fillEllipse(in: rim.insetBy(dx: 40, dy: 24).offsetBy(dx: 0, dy: 6))
    context.setFillColor(palette.tadka.cg())
    for (x, y, r) in [(430.0, 568.0, 11.0), (500.0, 596.0, 9.0), (575.0, 562.0, 12.0),
        (640.0, 590.0, 9.0), (372.0, 590.0, 8.0)]
    {
        context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    // A single curry leaf for colour and recognisability at small sizes.
    let leaf = CGMutablePath()
    leaf.move(to: CGPoint(x: 548, y: 600))
    leaf.addQuadCurve(to: CGPoint(x: 660, y: 548), control: CGPoint(x: 590, y: 540))
    leaf.addQuadCurve(to: CGPoint(x: 548, y: 600), control: CGPoint(x: 630, y: 610))
    context.setFillColor(palette.leaf.cg())
    context.addPath(leaf)
    context.fillPath()
}

func render(_ palette: Palette, to name: String) throws {
    // Opaque icons must carry no alpha channel (App Store rule); only the dark one is
    // transparent, so the system's dark backdrop shows through.
    let alpha: CGImageAlphaInfo = palette.backgroundTop == nil ? .premultipliedLast : .noneSkipLast
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: alpha.rawValue)
    else { throw CocoaError(.featureUnsupported) }
    draw(palette, in: context)
    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1,
            nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    print("wrote \(name)")
}

do {
    try render(light, to: "AppIcon.png")
    try render(dark, to: "AppIcon-Dark.png")
    try render(tinted, to: "AppIcon-Tinted.png")
} catch {
    FileHandle.standardError.write(Data("failed: \(error)\n".utf8))
    exit(1)
}
