// Gera AppIcon.icns a partir de icone-1024.png, no recorte arredondado padrão do macOS. Uso: swift make-icon.swift <pasta>
import AppKit

let dist = CommandLine.arguments[1]
let iconset = "\(dist)/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let arte = NSImage(contentsOfFile: "icone-1024.png")!

func desenhar(_ lado: Int) -> Data {
    let s = CGFloat(lado)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let m = s * 0.09, area = NSRect(x: m, y: m, width: s - 2 * m, height: s - 2 * m)
    let forma = NSBezierPath(roundedRect: area, xRadius: s * 0.19, yRadius: s * 0.19)
    forma.addClip()
    arte.draw(in: area)
    NSColor(white: 1, alpha: 0.16).setStroke()
    forma.lineWidth = s * 0.006
    forma.stroke()
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
