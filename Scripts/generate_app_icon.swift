import AppKit
import CoreGraphics

// RepForge NEXT icon — forged monogram, graphite glass, electric-lime impulse.
// Generated on the build runner; no image/font binaries are checked into source.
let edge: CGFloat = 1024
let artwork = NSImage(size: NSSize(width: edge, height: edge))
artwork.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Icon requires a drawing context")
}
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let space = CGColorSpaceCreateDeviceRGB()
let lime = NSColor(red: 0.81, green: 0.97, blue: 0.34, alpha: 1)
let background = CGGradient(
    colorsSpace: space,
    colors: [
        NSColor(red: 0.070, green: 0.092, blue: 0.125, alpha: 1).cgColor,
        NSColor(red: 0.018, green: 0.024, blue: 0.035, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(background, start: CGPoint(x: 20, y: 950),
                           end: CGPoint(x: 1000, y: 50), options: [])

let fog = CGGradient(colorsSpace: space, colors: [
    NSColor(red: 0.77, green: 0.95, blue: 0.30, alpha: 0.20).cgColor,
    NSColor.clear.cgColor
] as CFArray, locations: [0, 1])!
context.drawRadialGradient(fog, startCenter: CGPoint(x: 740, y: 720),
                           startRadius: 10, endCenter: CGPoint(x: 740, y: 720),
                           endRadius: 560, options: [])

let ring = NSBezierPath(ovalIn: NSRect(x: 132, y: 132, width: 760, height: 760))
ring.lineWidth = 12
NSColor(red: 0.35, green: 0.48, blue: 0.37, alpha: 0.18).setStroke()
ring.stroke()

// A heavy, forward-leaning initial gives the system a recognizable mark.
let font = NSFont(name: "AvenirNext-HeavyItalic", size: 650)
    ?? NSFont.systemFont(ofSize: 650, weight: .black)
let glow = NSShadow()
glow.shadowBlurRadius = 28
glow.shadowOffset = .zero
glow.shadowColor = lime.withAlphaComponent(0.58)
let mark = NSAttributedString(string: "R", attributes: [
    .font: font,
    .foregroundColor: NSColor(red: 0.91, green: 0.99, blue: 0.78, alpha: 1),
    .shadow: glow
])
mark.draw(in: NSRect(x: 275, y: 130, width: 570, height: 730))

// Momentum slash: the arc of the R breaks into a glowing forward vector.
let slash = NSBezierPath()
slash.move(to: NSPoint(x: 200, y: 365))
slash.line(to: NSPoint(x: 650, y: 365))
slash.lineWidth = 51
slash.lineCapStyle = .round
context.saveGState()
context.setShadow(offset: .zero, blur: 28, color: lime.withAlphaComponent(0.68).cgColor)
lime.setStroke()
slash.stroke()
context.restoreGState()

let core = NSBezierPath()
core.move(to: NSPoint(x: 215, y: 365))
core.line(to: NSPoint(x: 650, y: 365))
core.lineWidth = 18
core.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.95).setStroke()
core.stroke()

// Precision marker — three rising, slanted cuts.
for index in 0..<3 {
    let x = CGFloat(140 + index * 52)
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: x, y: 295))
    arrow.line(to: NSPoint(x: x + 35, y: 330))
    arrow.lineWidth = 12
    arrow.lineCapStyle = .round
    lime.withAlphaComponent(0.72).setStroke()
    arrow.stroke()
}

artwork.unlockFocus()
guard let tiff = artwork.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not export app icon")
}
let outputDirectory = "Sources/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(
    atPath: outputDirectory, withIntermediateDirectories: true
)
try data.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("AppIcon.png"))
print("Generated RepForge NEXT icon")
