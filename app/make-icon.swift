// Gera dist/AppIcon.icns: globo branco de linhas finas sobre fundo preto de vidro.
import AppKit

let dist = CommandLine.arguments[1]
let iconset = "\(dist)/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func desenhar(_ lado: Int) -> Data {
    let s = CGFloat(lado)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let m = s * 0.09
    let fundo = NSBezierPath(roundedRect: NSRect(x: m, y: m, width: s - 2 * m, height: s - 2 * m), xRadius: s * 0.19, yRadius: s * 0.19)
    NSGradient(starting: NSColor(white: 0.20, alpha: 1), ending: NSColor(white: 0.02, alpha: 1))!.draw(in: fundo, angle: -70)
    NSColor(white: 1, alpha: 0.18).setStroke()
    fundo.lineWidth = s * 0.006
    fundo.stroke()
    let r = s * 0.27, c = NSPoint(x: s / 2, y: s / 2)
    NSColor.white.setStroke()
    let globo = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    let meridiano = NSBezierPath(ovalIn: NSRect(x: c.x - r * 0.42, y: c.y - r, width: r * 0.84, height: 2 * r))
    let equador = NSBezierPath()
    equador.move(to: NSPoint(x: c.x - r, y: c.y)); equador.line(to: NSPoint(x: c.x + r, y: c.y))
    for p in [globo, meridiano, equador] { p.lineWidth = s * 0.016; p.stroke() }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (nome, lado) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                     ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try desenhar(lado).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(nome).png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", "\(dist)/AppIcon.icns"]
try p.run(); p.waitUntilExit()
