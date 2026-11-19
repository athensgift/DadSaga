import SwiftUI

/// A four-pointed sparkle, for celebrations and legendary items.
public struct Sparkle: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        let rad = min(rect.width, rect.height) / 2
        let pinch = rad * 0.28
        var path = Path()
        path.move(to: CGPoint(x: mid.x, y: mid.y - rad))
        path.addQuadCurve(to: CGPoint(x: mid.x + rad, y: mid.y), control: CGPoint(x: mid.x + pinch, y: mid.y - pinch))
        path.addQuadCurve(to: CGPoint(x: mid.x, y: mid.y + rad), control: CGPoint(x: mid.x + pinch, y: mid.y + pinch))
        path.addQuadCurve(to: CGPoint(x: mid.x - rad, y: mid.y), control: CGPoint(x: mid.x - pinch, y: mid.y + pinch))
        path.addQuadCurve(to: CGPoint(x: mid.x, y: mid.y - rad), control: CGPoint(x: mid.x - pinch, y: mid.y - pinch))
        return path
    }
}
