import CoreGraphics
import CoreText
import Foundation
import ImageIO

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make_menubar_icon.swift <destination>\n", stderr)
    exit(2)
}

let destinationURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 1024
let height = 256
let canvas = CGRect(x: 0, y: 0, width: width, height: height)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("error: could not create menu bar icon context\n", stderr)
    exit(1)
}

context.clear(canvas)
context.setFillColor(CGColor(red: 0.08, green: 0.47, blue: 0.95, alpha: 1))
context.addPath(CGPath(
    roundedRect: canvas,
    cornerWidth: 56,
    cornerHeight: 56,
    transform: nil
))
context.fillPath()

let text = "GPT-switch"
let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 148, nil)
let attributes: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
]
let attributedText = NSAttributedString(string: text, attributes: attributes)
let line = CTLineCreateWithAttributedString(attributedText)
let textBounds = CTLineGetBoundsWithOptions(line, [])
let textOrigin = CGPoint(
    x: (CGFloat(width) - textBounds.width) / 2 - textBounds.origin.x,
    y: (CGFloat(height) - textBounds.height) / 2 - textBounds.origin.y
)
context.textPosition = textOrigin
CTLineDraw(line, context)

guard let outputImage = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          destinationURL as CFURL,
          "public.png" as CFString,
          1,
          nil
      ) else {
    fputs("error: could not create menu bar icon output\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("error: could not write menu bar icon\n", stderr)
    exit(1)
}
