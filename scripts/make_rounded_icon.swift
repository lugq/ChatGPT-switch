import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 4,
      let size = Int(CommandLine.arguments[3]),
      size > 0 else {
    fputs("usage: make_rounded_icon.swift <source> <destination> <size>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let destinationURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("error: could not read source image\n", stderr)
    exit(1)
}

let canvas = CGRect(x: 0, y: 0, width: size, height: size)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("error: could not create image context\n", stderr)
    exit(1)
}

context.clear(canvas)
context.interpolationQuality = .high
context.addPath(CGPath(
    roundedRect: canvas,
    cornerWidth: CGFloat(size) * 0.22,
    cornerHeight: CGFloat(size) * 0.22,
    transform: nil
))
context.clip()
context.draw(sourceImage, in: canvas)

guard let outputImage = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          destinationURL as CFURL,
          UTType.png.identifier as CFString,
          1,
          nil
      ) else {
    fputs("error: could not create destination image\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("error: could not write destination image\n", stderr)
    exit(1)
}
