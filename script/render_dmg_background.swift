import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: render_dmg_background.swift SOURCE.svg OUTPUT.png\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let targetSize = NSSize(width: 900, height: 520)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Could not load SVG background: \(sourceURL.path)\n", stderr)
    exit(1)
}
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let bitmapContext = CGContext(
        data: nil,
        width: Int(targetSize.width),
        height: Int(targetSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    fputs("Could not allocate PNG bitmap.\n", stderr)
    exit(1)
}
let graphicsContext = NSGraphicsContext(cgContext: bitmapContext, flipped: false)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
sourceImage.draw(in: NSRect(origin: .zero, size: targetSize))
NSGraphicsContext.restoreGraphicsState()

guard let renderedImage = bitmapContext.makeImage() else {
    fputs("Could not create PNG image.\n", stderr)
    exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: renderedImage)
guard let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    fputs("Could not encode PNG background.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: outputURL, options: Data.WritingOptions.atomic)
} catch {
    fputs("Could not write PNG background: \(error.localizedDescription)\n", stderr)
    exit(1)
}
