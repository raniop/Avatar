import SpriteKit
import UIKit

/// Generates high-quality game textures using CoreGraphics.
/// These look significantly better than SKShapeNode primitives.
enum GameTexture {

    // MARK: - Football

    static func football(radius: CGFloat) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: radius, y: radius)

            // Shadow
            cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.4).cgColor)

            // Base white circle with gradient
            let ballRect = CGRect(x: 2, y: 2, width: radius * 2 - 4, height: radius * 2 - 4)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [UIColor.white.cgColor, UIColor(white: 0.85, alpha: 1).cgColor] as CFArray,
                                       locations: [0, 1])!
            cg.saveGState()
            cg.addEllipse(in: ballRect)
            cg.clip()
            cg.drawLinearGradient(gradient, start: CGPoint(x: radius * 0.3, y: radius * 0.2),
                                   end: CGPoint(x: radius * 1.5, y: radius * 1.8), options: [])
            cg.restoreGState()

            cg.setShadow(offset: .zero, blur: 0)

            // Pentagon pattern
            let pentagonRadius: CGFloat = radius * 0.28
            let pentagons: [(CGFloat, CGFloat)] = [
                (0, 0), // center
                (0, -radius * 0.55),
                (radius * 0.52, -radius * 0.17),
                (radius * 0.32, radius * 0.45),
                (-radius * 0.32, radius * 0.45),
                (-radius * 0.52, -radius * 0.17),
            ]

            for (dx, dy) in pentagons {
                let px = center.x + dx
                let py = center.y + dy
                drawPentagon(in: cg, center: CGPoint(x: px, y: py), radius: pentagonRadius,
                             fill: UIColor(white: 0.15, alpha: 0.9))
            }

            // Seam lines between pentagons
            cg.setStrokeColor(UIColor(white: 0.3, alpha: 0.4).cgColor)
            cg.setLineWidth(1.0)
            for i in 1..<pentagons.count {
                let (dx, dy) = pentagons[i]
                cg.move(to: CGPoint(x: center.x, y: center.y))
                cg.addLine(to: CGPoint(x: center.x + dx * 1.3, y: center.y + dy * 1.3))
            }
            cg.strokePath()

            // Highlight (specular)
            let highlightRect = CGRect(x: radius * 0.55, y: radius * 0.3, width: radius * 0.6, height: radius * 0.45)
            let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                colors: [UIColor.white.withAlphaComponent(0.6).cgColor,
                                                         UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                                locations: [0, 1])!
            cg.saveGState()
            cg.addEllipse(in: highlightRect)
            cg.clip()
            cg.drawRadialGradient(highlightGradient,
                                   startCenter: CGPoint(x: highlightRect.midX, y: highlightRect.midY),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: highlightRect.midX, y: highlightRect.midY),
                                   endRadius: highlightRect.width / 2, options: [])
            cg.restoreGState()

            // Edge darkening
            cg.saveGState()
            cg.addEllipse(in: ballRect)
            cg.clip()
            let edgeGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                           colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.15).cgColor] as CFArray,
                                           locations: [0.6, 1.0])!
            cg.drawRadialGradient(edgeGradient,
                                   startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius - 2, options: [])
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    private static func drawPentagon(in ctx: CGContext, center: CGPoint, radius: CGFloat, fill: UIColor) {
        ctx.saveGState()
        let path = CGMutablePath()
        for i in 0..<5 {
            let angle = CGFloat(i) * (2 * .pi / 5) - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(fill.cgColor)
        ctx.fillPath()
        ctx.addPath(path)
        ctx.setStrokeColor(UIColor(white: 0.3, alpha: 0.5).cgColor)
        ctx.setLineWidth(0.8)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Grass Field

    static func grassField(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // Base gradient (darker at top = further away)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor(red: 0.12, green: 0.38, blue: 0.12, alpha: 1).cgColor,
                                           UIColor(red: 0.18, green: 0.52, blue: 0.18, alpha: 1).cgColor,
                                           UIColor(red: 0.22, green: 0.6, blue: 0.2, alpha: 1).cgColor,
                                       ] as CFArray,
                                       locations: [0, 0.5, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            // Grass stripes (light/dark alternating like a real pitch)
            let stripeCount = 12
            let stripeH = size.height / CGFloat(stripeCount)
            for i in 0..<stripeCount {
                if i % 2 == 0 { continue }
                let rect = CGRect(x: 0, y: CGFloat(i) * stripeH, width: size.width, height: stripeH)
                cg.setFillColor(UIColor.white.withAlphaComponent(0.04).cgColor)
                cg.fill(rect)
            }

            // Subtle grass texture (random tiny lines)
            for _ in 0..<200 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let length = CGFloat.random(in: 3...8)
                let angle = CGFloat.random(in: -0.3...0.3)
                cg.saveGState()
                cg.translateBy(x: x, y: y)
                cg.rotate(by: angle)
                cg.setStrokeColor(UIColor(red: 0.3, green: 0.7, blue: 0.25, alpha: 0.12).cgColor)
                cg.setLineWidth(1)
                cg.move(to: .zero)
                cg.addLine(to: CGPoint(x: 0, y: -length))
                cg.strokePath()
                cg.restoreGState()
            }
        }
        return SKTexture(image: image)
    }

    // MARK: - Goal Net

    static func goalNet(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // Dark background
            cg.setFillColor(UIColor(white: 0, alpha: 0.4).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Net pattern with perspective (narrower at top)
            let spacing: CGFloat = 10
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
            cg.setLineWidth(0.8)

            // Vertical lines (converging slightly toward top for depth)
            for col in 0...cols {
                let bottomX = CGFloat(col) * spacing
                let topX = size.width * 0.1 + (bottomX / size.width) * size.width * 0.8
                cg.move(to: CGPoint(x: bottomX, y: size.height))
                cg.addLine(to: CGPoint(x: topX, y: 0))
            }
            cg.strokePath()

            // Horizontal lines
            for row in 0...rows {
                let y = CGFloat(row) * spacing
                let progress = y / size.height
                let inset = (1 - progress) * size.width * 0.1
                cg.move(to: CGPoint(x: inset, y: y))
                cg.addLine(to: CGPoint(x: size.width - inset, y: y))
            }
            cg.strokePath()
        }
        return SKTexture(image: image)
    }

    // MARK: - Goal Post (metallic)

    static func goalPost(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // Metallic gradient
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor(white: 0.95, alpha: 1).cgColor,
                                           UIColor(white: 0.75, alpha: 1).cgColor,
                                           UIColor(white: 0.9, alpha: 1).cgColor,
                                           UIColor(white: 0.7, alpha: 1).cgColor,
                                       ] as CFArray,
                                       locations: [0, 0.3, 0.7, 1])!
            let rect = CGRect(origin: .zero, size: size)
            cg.addRect(rect)
            cg.clip()
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])

            // Subtle shadow on right edge
            cg.setFillColor(UIColor.black.withAlphaComponent(0.1).cgColor)
            cg.fill(CGRect(x: size.width * 0.8, y: 0, width: size.width * 0.2, height: size.height))
        }
        return SKTexture(image: image)
    }

    // MARK: - Basketball

    static func basketball(radius: CGFloat) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: radius, y: radius)
            let ballRect = CGRect(x: 2, y: 2, width: radius * 2 - 4, height: radius * 2 - 4)

            // Shadow
            cg.setShadow(offset: CGSize(width: 0, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.4).cgColor)

            // Orange gradient
            cg.saveGState()
            cg.addEllipse(in: ballRect)
            cg.clip()
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 1).cgColor,
                                           UIColor(red: 0.85, green: 0.35, blue: 0.05, alpha: 1).cgColor,
                                       ] as CFArray,
                                       locations: [0.2, 1])!
            cg.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: radius * 0.7, y: radius * 0.6),
                                   startRadius: 0,
                                   endCenter: center, endRadius: radius, options: [])
            cg.restoreGState()
            cg.setShadow(offset: .zero, blur: 0)

            // Seam lines (the characteristic basketball lines)
            cg.saveGState()
            cg.addEllipse(in: ballRect)
            cg.clip()
            cg.setStrokeColor(UIColor(red: 0.3, green: 0.15, blue: 0, alpha: 0.5).cgColor)
            cg.setLineWidth(2.0)

            // Horizontal seam
            cg.move(to: CGPoint(x: 2, y: radius))
            cg.addLine(to: CGPoint(x: radius * 2 - 2, y: radius))
            cg.strokePath()

            // Vertical seam
            cg.move(to: CGPoint(x: radius, y: 2))
            cg.addLine(to: CGPoint(x: radius, y: radius * 2 - 2))
            cg.strokePath()

            // Curved seams
            let curvePath1 = CGMutablePath()
            curvePath1.move(to: CGPoint(x: radius * 0.3, y: 4))
            curvePath1.addQuadCurve(to: CGPoint(x: radius * 0.3, y: radius * 2 - 4),
                                     control: CGPoint(x: radius * 0.6, y: radius))
            cg.addPath(curvePath1)
            cg.strokePath()

            let curvePath2 = CGMutablePath()
            curvePath2.move(to: CGPoint(x: radius * 1.7, y: 4))
            curvePath2.addQuadCurve(to: CGPoint(x: radius * 1.7, y: radius * 2 - 4),
                                     control: CGPoint(x: radius * 1.4, y: radius))
            cg.addPath(curvePath2)
            cg.strokePath()
            cg.restoreGState()

            // Pebble texture (tiny dots)
            cg.saveGState()
            cg.addEllipse(in: ballRect)
            cg.clip()
            for _ in 0..<100 {
                let px = CGFloat.random(in: 4...(radius * 2 - 4))
                let py = CGFloat.random(in: 4...(radius * 2 - 4))
                let dist = hypot(px - radius, py - radius)
                guard dist < radius - 3 else { continue }
                cg.setFillColor(UIColor(white: 0, alpha: CGFloat.random(in: 0.02...0.06)).cgColor)
                cg.fillEllipse(in: CGRect(x: px, y: py, width: 1.5, height: 1.5))
            }
            cg.restoreGState()

            // Specular highlight
            cg.saveGState()
            let hlRect = CGRect(x: radius * 0.5, y: radius * 0.25, width: radius * 0.7, height: radius * 0.5)
            cg.addEllipse(in: hlRect)
            cg.clip()
            let hlGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [UIColor.white.withAlphaComponent(0.35).cgColor,
                                                  UIColor.clear.cgColor] as CFArray,
                                         locations: [0, 1])!
            cg.drawRadialGradient(hlGradient,
                                   startCenter: CGPoint(x: hlRect.midX, y: hlRect.midY),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: hlRect.midX, y: hlRect.midY),
                                   endRadius: hlRect.width / 2, options: [])
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    // MARK: - Letter Bubble (for items/targets)

    static func letterBubble(size: CGFloat, color: UIColor, glowColor: UIColor? = nil) -> SKTexture {
        let padding: CGFloat = 8
        let totalSize = CGSize(width: size + padding * 2, height: size + padding * 2)
        let renderer = UIGraphicsImageRenderer(size: totalSize)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: totalSize.width / 2, y: totalSize.height / 2)
            let radius = size / 2

            // Outer glow
            if let glow = glowColor {
                cg.setShadow(offset: .zero, blur: 12, color: glow.withAlphaComponent(0.5).cgColor)
            }

            // Circle with gradient
            let circleRect = CGRect(x: padding, y: padding, width: size, height: size)
            cg.saveGState()
            cg.addEllipse(in: circleRect)
            cg.clip()

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           color.withAlphaComponent(0.95).cgColor,
                                           color.adjustBrightness(by: -0.2).cgColor,
                                       ] as CFArray,
                                       locations: [0.3, 1])!
            cg.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.2),
                                   startRadius: 0,
                                   endCenter: center, endRadius: radius, options: [])
            cg.restoreGState()

            // Border
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(2.5)
            cg.strokeEllipse(in: circleRect.insetBy(dx: 1, dy: 1))

            // Highlight
            cg.saveGState()
            let hlRect = CGRect(x: center.x - radius * 0.5, y: center.y - radius * 0.8,
                                width: radius, height: radius * 0.6)
            cg.addEllipse(in: hlRect)
            cg.clip()
            let hlGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [UIColor.white.withAlphaComponent(0.3).cgColor,
                                              UIColor.clear.cgColor] as CFArray,
                                     locations: [0, 1])!
            cg.drawRadialGradient(hlGrad,
                                   startCenter: CGPoint(x: hlRect.midX, y: hlRect.midY),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: hlRect.midX, y: hlRect.midY),
                                   endRadius: hlRect.width / 2, options: [])
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    // MARK: - Wooden Court Floor

    static func woodenFloor(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // Base color
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor(red: 0.72, green: 0.52, blue: 0.32, alpha: 1).cgColor,
                                           UIColor(red: 0.58, green: 0.4, blue: 0.24, alpha: 1).cgColor,
                                       ] as CFArray,
                                       locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            // Wood plank lines
            let plankWidth: CGFloat = 28
            for x in stride(from: CGFloat(0), to: size.width, by: plankWidth) {
                cg.setStrokeColor(UIColor(white: 0, alpha: 0.08).cgColor)
                cg.setLineWidth(1)
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: size.height))
                cg.strokePath()
            }

            // Wood grain
            for _ in 0..<80 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let w = CGFloat.random(in: 20...60)
                cg.setStrokeColor(UIColor(red: 0.5, green: 0.35, blue: 0.2, alpha: CGFloat.random(in: 0.05...0.12)).cgColor)
                cg.setLineWidth(0.8)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x + w, y: y + CGFloat.random(in: -2...2)))
                cg.strokePath()
            }

            // Floor reflection/shine
            let shineGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [UIColor.white.withAlphaComponent(0.08).cgColor,
                                                 UIColor.clear.cgColor] as CFArray,
                                        locations: [0, 1])!
            cg.drawLinearGradient(shineGrad, start: CGPoint(x: 0, y: size.height * 0.3),
                                   end: CGPoint(x: 0, y: size.height * 0.7), options: [])
        }
        return SKTexture(image: image)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    func adjustBrightness(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, min(1, b + amount)), alpha: a)
    }
}
