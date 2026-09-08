import Foundation
import CoreGraphics

public struct NormalizedCrop: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double = 0, y: Double = 0, width: Double = 1, height: Double = 1) { self.x = x; self.y = y; self.width = width; self.height = height }
    public func pixels(width sourceWidth: Int, height sourceHeight: Int, even: Bool = false) throws -> CGRect {
        guard [x, y, width, height].allSatisfy(\.isFinite), x >= 0, y >= 0, width > 0, height > 0, x + width <= 1.000001, y + height <= 1.000001 else { throw ConvertyError.message("The crop must stay inside the image.") }
        let unit = even ? 2 : 1
        let w = Int((width * Double(sourceWidth)).rounded(.down)) / unit * unit
        let h = Int((height * Double(sourceHeight)).rounded(.down)) / unit * unit
        guard w >= unit, h >= unit else { throw ConvertyError.message("The crop is too small.") }
        let left = min(sourceWidth - w, Int(x * Double(sourceWidth)) / unit * unit)
        let top = min(sourceHeight - h, Int(y * Double(sourceHeight)) / unit * unit)
        return CGRect(x: left, y: top, width: w, height: h)
    }
}

public struct WheelGeometry: Sendable {
    public let center: CGPoint
    public let innerRadius: Double
    public let outerRadius: Double
    public init(center: CGPoint = CGPoint(x: 180, y: 180), innerRadius: Double = 66, outerRadius: Double = 164) { self.center = center; self.innerRadius = innerRadius; self.outerRadius = outerRadius }
    public func index(at point: CGPoint, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let dx = point.x - center.x, dy = point.y - center.y
        let radius = hypot(dx, dy)
        guard radius >= innerRadius, radius <= outerRadius else { return nil }
        let step = 2 * Double.pi / Double(count)
        let angle = (atan2(dy, dx) + Double.pi / 2 + step / 2 + 2 * Double.pi).truncatingRemainder(dividingBy: 2 * Double.pi)
        let offset = angle.truncatingRemainder(dividingBy: step)
        guard offset > 0.055, offset < step - 0.055 else { return nil }
        return min(count - 1, Int(angle / step))
    }
    public static func frame(center: CGPoint, size: CGSize, screen: CGRect) -> CGRect {
        CGRect(x: min(max(center.x - size.width / 2, screen.minX), max(screen.minX, screen.maxX - size.width)), y: min(max(center.y - size.height / 2, screen.minY), max(screen.minY, screen.maxY - size.height)), width: size.width, height: size.height)
    }
}
