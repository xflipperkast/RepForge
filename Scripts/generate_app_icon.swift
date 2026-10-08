import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create graphics context")
}
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// Deep navy / charcoal background matching RepForge.
let bgColors = [
    NSColor(red: 0.015, green: 0.035, blue: 0.065, alpha: 1).cgColor,
    NSColor(red: 0.025, green: 0.080, blue: 0.150, alpha: 1).cgColor,
    NSColor(red: 0.005, green: 0.015, blue: 0.030, alpha: 1).cgColor
] as CFArray
let bgLocations: [CGFloat] = [0.0, 0.44, 1.0]
let bgSpace = CGColorSpaceCreateDeviceRGB()
let bg = CGGradient(colorsSpace: bgSpace, colors: bgColors, locations: bgLocations)!
ctx.drawLinearGradient(
    bg,
    start: CGPoint(x: 100, y: 950),
    end: CGPoint(x: 900, y: 40),
    options: []
)

// Soft blue halo behind the emblem.
let haloColors = [
    NSColor(red: 0.05, green: 0.55, blue: 1.0, alpha: 0.25).cgColor,
    NSColor.clear.cgColor
] as CFArray
let halo = CGGradient(colorsSpace: bgSpace, colors: haloColors, locations: [0, 1])!
ctx.drawRadialGradient(
    halo,
    startCenter: CGPoint(x: 500, y: 500),
    startRadius: 20,
    endCenter: CGPoint(x: 500, y: 500),
    endRadius: 500,
    options: []
)

func roundedRect(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func glowRect(_ rect: CGRect, radius: CGFloat, glow: NSColor, blur: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: blur, color: glow.cgColor)
    roundedRect(rect, radius: radius, color: glow)
    ctx.restoreGState()
}

// Main forged "R".
let rFont = NSFont(name: "AvenirNext-HeavyItalic", size: 610)
    ?? NSFont.systemFont(ofSize: 610, weight: .heavy)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let rShadow = NSShadow()
rShadow.shadowColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.85)
rShadow.shadowBlurRadius = 26
rShadow.shadowOffset = .zero

let rAttributes: [NSAttributedString.Key: Any] = [
    .font: rFont,
    .foregroundColor: NSColor(calibratedWhite: 0.76, alpha: 1),
    .paragraphStyle: paragraph,
    .shadow: rShadow
]

let rString = NSAttributedString(string: "R", attributes: rAttributes)
rString.draw(in: NSRect(x: 310, y: 170, width: 650, height: 690))

// Dark inner cut to visually integrate the bar with the R.
roundedRect(CGRect(x: 425, y: 455, width: 345, height: 120),
            radius: 60,
            color: NSColor(red: 0.012, green: 0.025, blue: 0.050, alpha: 1))

// Electric blue bar glow.
glowRect(CGRect(x: 230, y: 480, width: 520, height: 74),
         radius: 37,
         glow: NSColor(red: 0.0, green: 0.54, blue: 1.0, alpha: 0.52),
         blur: 34)

// Metallic dumbbell shaft.
let shaftGradient = NSGradient(colors: [
    NSColor(calibratedWhite: 0.93, alpha: 1),
    NSColor(calibratedWhite: 0.45, alpha: 1),
    NSColor(calibratedWhite: 0.80, alpha: 1)
])!
let shaftPath = NSBezierPath(roundedRect: NSRect(x: 240, y: 492, width: 510, height: 50),
                             xRadius: 25, yRadius: 25)
shaftGradient.draw(in: shaftPath, angle: -90)

// Plates with blue rim highlights.
let plateRects = [
    CGRect(x: 150, y: 444, width: 55, height: 146),
    CGRect(x: 205, y: 410, width: 72, height: 214),
    CGRect(x: 277, y: 360, width: 96, height: 314)
]

for (index, rect) in plateRects.enumerated() {
    let glowAlpha: CGFloat = index == 2 ? 0.58 : 0.45
    glowRect(rect.insetBy(dx: -3, dy: -3),
             radius: rect.width * 0.30,
             glow: NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: glowAlpha),
             blur: 22)

    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.27, yRadius: rect.width * 0.27)
    let metal = NSGradient(colors: [
        NSColor(calibratedWhite: 0.92, alpha: 1),
        NSColor(calibratedWhite: 0.38, alpha: 1),
        NSColor(calibratedWhite: 0.73, alpha: 1)
    ])!
    metal.draw(in: path, angle: 0)
}

// Small outer collar.
roundedRect(CGRect(x: 120, y: 466, width: 34, height: 102),
            radius: 14,
            color: NSColor(calibratedWhite: 0.52, alpha: 1))

// Crisp electric-blue accent line.
roundedRect(CGRect(x: 375, y: 487, width: 365, height: 8),
            radius: 4,
            color: NSColor(red: 0.0, green: 0.62, blue: 1.0, alpha: 0.95))

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to encode app icon")
}

let fm = FileManager.default
let directory = "Sources/Assets.xcassets/AppIcon.appiconset"
try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
let output = URL(fileURLWithPath: directory).appendingPathComponent("AppIcon.png")
try png.write(to: output)
print("Generated \(output.path)")
