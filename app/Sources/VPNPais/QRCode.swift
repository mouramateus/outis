import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

func imagemQR(_ texto: String) -> NSImage? {
    let f = CIFilter.qrCodeGenerator()
    f.message = Data(texto.utf8)
    f.correctionLevel = "M"
    guard let ci = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
          let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: ci.extent.width, height: ci.extent.height))
}
