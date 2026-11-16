// Run from the repository root: swift ios/branding/generate_app_icon.swift
// Geometry: BrandMark/_BrandMarkPainter in lib/ui/components.dart.
// Colors: Brand.navy, Brand.lane, and the white Login logo background.
// Only the iOS catalog is written. No Flutter build or external packages needed.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let branding = root.appendingPathComponent("ios/branding")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let navy = CGColor(colorSpace: colorSpace, components: [CGFloat(4) / 255, CGFloat(21) / 255, CGFloat(101) / 255, 1])!
let lane = CGColor(colorSpace: colorSpace, components: [CGFloat(252) / 255, CGFloat(196) / 255, CGFloat(25) / 255, 1])!

func context(_ pixels: Int) -> CGContext {
    CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
              bytesPerRow: pixels * 4, space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}

// Supersample the vector mark for clean edges at every catalog size.
let large = context(4096)
large.setFillColor(CGColor(gray: 1, alpha: 1))
large.fill(CGRect(x: 0, y: 0, width: 4096, height: 4096))
large.scaleBy(x: 4, y: 4)
large.translateBy(x: 0, y: 1024)
large.scaleBy(x: 1, y: -1)
// Ink bounds of the original painter: x=0...398, y=-1...275.
// Center those bounds with 128 px horizontal padding; no rounded mask.
let scale: CGFloat = 768 / 398
large.translateBy(x: 128, y: 512 - 137 * scale)
large.scaleBy(x: scale, y: scale)
large.setStrokeColor(navy)
large.setLineWidth(22)
large.setLineJoin(.miter)
large.setMiterLimit(4)
large.setLineCap(.butt)

func outline(_ x: CGFloat, _ endX: CGFloat, _ radiusX: CGFloat, closed: Bool) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: 10))
    path.addLine(to: CGPoint(x: endX, y: 10))
    let ellipse = CGAffineTransform(a: radiusX, b: 0, c: 0, d: 127, tx: endX, ty: 137)
    path.addArc(center: .zero, radius: 1, startAngle: -.pi / 2,
                endAngle: .pi / 2, clockwise: false, transform: ellipse)
    path.addLine(to: CGPoint(x: x, y: 264))
    if closed { path.closeSubpath() }
    large.addPath(path)
    large.strokePath()
}
outline(60, 156, 100, closed: true)
outline(212, 286, 101, closed: false)
let bridge = CGMutablePath()
bridge.move(to: CGPoint(x: 189, y: 54))
bridge.addLine(to: CGPoint(x: 208, y: 72))
bridge.addLine(to: CGPoint(x: 208, y: 206))
bridge.addLine(to: CGPoint(x: 189, y: 221))
bridge.closeSubpath()
large.setFillColor(navy)
large.addPath(bridge)
large.fillPath()
large.setFillColor(lane)
large.fill(CGRect(x: 0, y: 139, width: 166, height: 21))
let source = large.makeImage()!

func writePNG(_ url: URL, pixels: Int) {
    let output = context(pixels)
    output.interpolationQuality = .high
    output.draw(source, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, output.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination), "Cannot write \(url.lastPathComponent)")
}

writePNG(branding.appendingPathComponent("customer-app-icon-1024.png"), pixels: 1024)
let data = try Data(contentsOf: catalog.appendingPathComponent("Contents.json"))
let contents = try JSONSerialization.jsonObject(with: data) as! [String: Any]
var written = Set<String>()
for entry in contents["images"] as! [[String: String]] {
    let filename = entry["filename"]!
    guard written.insert(filename).inserted else { continue }
    let points = Double(entry["size"]!.components(separatedBy: "x")[0])!
    let multiplier = Double(entry["scale"]!.dropLast())!
    writePNG(catalog.appendingPathComponent(filename), pixels: Int(points * multiplier))
}
print("Generated opaque 1024px master and \(written.count) iOS icon files.")
