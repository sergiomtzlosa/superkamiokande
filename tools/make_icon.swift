// make_icon.swift — renders the Super-Kamiokande app icon (1024×1024 PNG).
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

func withShadow(_ color: NSColor, radius: CGFloat, _ body: () -> Void) {
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = radius
    shadow.shadowOffset = NSSize(width: 0, height: 0)
    shadow.set()
    body()
}

// Background rounded square, deep-space gradient.
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                      xRadius: 180, yRadius: 180)
bg.addClip()
let bgGrad = NSGradient(colors: [
    col(0.08, 0.11, 0.20),
    col(0.02, 0.04, 0.09)
])!
bgGrad.draw(in: bg, angle: -90)

// Subtle water-line glow behind the tank.
withShadow(col(0.2, 0.5, 1.0, 0.6), radius: 90) {}

let cx: CGFloat = 512
let tankW: CGFloat = 470
let tankH: CGFloat = 700
let tankRect = NSRect(x: cx - tankW/2, y: 110, width: tankW, height: tankH)

func capsule(_ rect: NSRect, inset: CGFloat) -> NSBezierPath {
    let inner = rect.insetBy(dx: inset, dy: inset)
    let r = inner.width / 2
    let bc = NSPoint(x: inner.midX, y: inner.minY + r)   // bottom arc centre
    let tc = NSPoint(x: inner.midX, y: inner.maxY - r)   // top arc centre
    let p = NSBezierPath()
    p.move(to: NSPoint(x: inner.minX, y: inner.minY + r))
    p.appendArc(withCenter: bc, radius: r, startAngle: 180, endAngle: 360)
    p.appendArc(withCenter: tc, radius: r, startAngle: 0, endAngle: 180)
    p.close()
    return p
}


// 1) Stainless steel shell.
let shell = capsule(tankRect, inset: 0)
let steel = NSGradient(colors: [
    col(0.78, 0.82, 0.88),
    col(0.50, 0.55, 0.62),
    col(0.70, 0.74, 0.82)
])!
withShadow(col(0, 0, 0, 0.8), radius: 30) {
    steel.draw(in: shell, angle: -90)
}

// 2) Water interior.
let water = capsule(tankRect, inset: 30)
let waterGrad = NSGradient(colors: [
    col(0.16, 0.45, 0.88),
    col(0.05, 0.18, 0.55)
])!
waterGrad.draw(in: water, angle: -90)

// 3) Everything else is clipped to the water body.
water.addClip()

// PMT dots (gold, staggered rows).
let dot: CGFloat = 34
for row in 0..<10 {
    let y = tankRect.minY + 90 + CGFloat(row) * (tankH - 190) / 9.0
    for i in 0..<6 {
        let x = cx - 165 + CGFloat(i) * 66 + (row % 2 == 0 ? 0 : 33)
        let p = NSBezierPath(ovalIn: NSRect(x: x - dot/2, y: y - dot, width: dot, height: dot))
        col(0.95, 0.82, 0.42, 0.95).setFill()
        p.fill()
    }
}

// Glowing Cherenkov ring.
let ringR: CGFloat = 140
let ringC = NSPoint(x: cx + 40, y: tankRect.minY + 330)
let glow = NSBezierPath(ovalIn: NSRect(x: ringC.x - ringR, y: ringC.y - ringR,
                                       width: ringR*2, height: ringR*2))
withShadow(col(0.30, 0.85, 1.0, 1), radius: 55) {
    col(0.45, 0.95, 1.0).setStroke()
    glow.lineWidth = 30
    glow.stroke()
}
col(0.80, 0.98, 1.0).setStroke()
glow.lineWidth = 9
glow.stroke()

// Muon track passing through the ring center.
let track = NSBezierPath()
track.move(to: NSPoint(x: cx - 165, y: ringC.y + 165))
track.line(to: NSPoint(x: cx + 195, y: ringC.y - 165))
track.lineWidth = 16
track.lineCapStyle = .round
withShadow(col(1.0, 0.35, 0.75, 1), radius: 35) {
    col(1.0, 0.60, 0.85).setStroke()
    track.stroke()
}

NSGraphicsContext.current?.restoreGraphicsState()

// 4) "SK" label bottom-center.
let para = NSMutableParagraphStyle()
para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 120, weight: .heavy),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para,
]
let title = NSAttributedString(string: "SK", attributes: attrs)
title.draw(at: NSPoint(x: cx - title.size().width/2 + 12,
                       y: tankRect.minY + 46))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not render png")
}
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
