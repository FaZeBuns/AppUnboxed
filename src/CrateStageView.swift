import SwiftUI
import UIKit

/// The pre-spin cinematic: a real 3D crate (six faces in a shared 3D space)
/// drops in, rattles in two escalating bursts while light leaks from its
/// seams, blows its lid open with a light beam and sparks, then the camera
/// dives into the opening and whites out into the reel.
struct CrateOpeningView: UIViewRepresentable {
    let onFinished: () -> Void

    func makeUIView(context: Context) -> CrateStageView {
        let view = CrateStageView()
        view.onFinished = onFinished
        return view
    }

    func updateUIView(_ uiView: CrateStageView, context: Context) {}
}

final class CrateStageView: UIView {

    var onFinished: (() -> Void)?

    // Timeline (seconds from start). The soundtrack is cut to these marks.
    private enum T {
        static let land = 0.32
        static let burst1 = 0.80
        static let burst1End = 1.15
        static let burst2 = 1.30
        static let pop = 2.05
        static let dive = 2.50
        static let end = 3.15
    }

    private let amber = UIColor(red: 1.0, green: 0.78, blue: 0.10, alpha: 1)

    private let backdrop = CAGradientLayer()
    private let floorGlow = CAGradientLayer()
    private let perspective = CALayer()
    private let mover = CATransformLayer()
    private let tilt = CATransformLayer()
    private let yaw = CATransformLayer()
    private let lidHinge = CATransformLayer()
    private let innerGlow = CAGradientLayer()
    private let beam = CAGradientLayer()
    private let emitter = CAEmitterLayer()
    private let flash = CALayer()
    private let whiteout = CALayer()
    private var seams: [CALayer] = []
    private var side: CGFloat = 170
    private var started = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = true   // swallow taps during the cinematic
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !started, bounds.width > 50, bounds.height > 50 else { return }
        started = true
        side = max(120, min(240, min(bounds.width, bounds.height) * 0.34))
        buildScene()
        play()
    }

    // MARK: - Scene

    private func buildScene() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY + side * 0.12)

        backdrop.type = .radial
        backdrop.colors = [UIColor(red: 0.13, green: 0.12, blue: 0.20, alpha: 1).cgColor,
                           UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1).cgColor,
                           UIColor.black.cgColor]
        backdrop.locations = [0, 0.55, 1]
        backdrop.startPoint = CGPoint(x: 0.5, y: 0.5)
        backdrop.endPoint = CGPoint(x: 1.0, y: 1.0)
        backdrop.frame = bounds
        layer.addSublayer(backdrop)

        // Pool of light on the floor under the crate.
        floorGlow.type = .radial
        floorGlow.colors = [amber.withAlphaComponent(0.42).cgColor, amber.withAlphaComponent(0).cgColor]
        floorGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        floorGlow.endPoint = CGPoint(x: 1, y: 1)
        floorGlow.bounds = CGRect(x: 0, y: 0, width: side * 3.4, height: side * 1.1)
        floorGlow.position = CGPoint(x: center.x, y: center.y + side * 0.78)
        floorGlow.opacity = 0
        layer.addSublayer(floorGlow)

        perspective.frame = bounds
        var p = CATransform3DIdentity
        p.m34 = -1.0 / (side * 5.2)
        perspective.sublayerTransform = p
        layer.addSublayer(perspective)

        mover.position = center
        perspective.addSublayer(mover)
        tilt.transform = CATransform3DMakeRotation(-0.44, 1, 0, 0)
        mover.addSublayer(tilt)
        yaw.transform = CATransform3DMakeRotation(0.62, 0, 1, 0)
        tilt.addSublayer(yaw)

        let h = side / 2
        let rect = CGRect(x: 0, y: 0, width: side, height: side)

        func face(_ image: UIImage, _ transform: CATransform3D, seam: Bool) {
            let f = CALayer()
            f.bounds = rect
            f.contents = image.cgImage
            f.transform = transform
            f.isDoubleSided = true
            f.allowsEdgeAntialiasing = true
            yaw.addSublayer(f)
            if seam {
                let s = CALayer()
                s.frame = CGRect(x: 4, y: -2, width: side - 8, height: 5)
                s.backgroundColor = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1).cgColor
                s.shadowColor = amber.cgColor
                s.shadowRadius = 14
                s.shadowOpacity = 1
                s.shadowOffset = .zero
                s.opacity = 0
                f.addSublayer(s)
                seams.append(s)
            }
        }

        let front = CrateArt.face(side: side, kind: .front, shade: 1.0)
        let right = CrateArt.face(side: side, kind: .side, shade: 0.72)
        let left = CrateArt.face(side: side, kind: .side, shade: 0.62)
        let back = CrateArt.face(side: side, kind: .plain, shade: 0.5)
        let bottom = CrateArt.face(side: side, kind: .plain, shade: 0.35)
        let lidArt = CrateArt.face(side: side, kind: .lid, shade: 1.22)

        face(front, CATransform3DMakeTranslation(0, 0, h), seam: true)
        face(back, CATransform3DTranslate(CATransform3DMakeRotation(.pi, 0, 1, 0), 0, 0, h), seam: true)
        face(right, CATransform3DTranslate(CATransform3DMakeRotation(.pi / 2, 0, 1, 0), 0, 0, h), seam: true)
        face(left, CATransform3DTranslate(CATransform3DMakeRotation(-.pi / 2, 0, 1, 0), 0, 0, h), seam: true)
        face(bottom, CATransform3DTranslate(CATransform3DMakeRotation(-.pi / 2, 1, 0, 0), 0, 0, h), seam: false)

        // Glowing surface just under the rim: the "light inside the box".
        innerGlow.type = .radial
        innerGlow.colors = [UIColor.white.cgColor,
                            UIColor(red: 1, green: 0.92, blue: 0.45, alpha: 1).cgColor,
                            UIColor(red: 1, green: 0.62, blue: 0.05, alpha: 1).cgColor]
        innerGlow.locations = [0, 0.45, 1]
        innerGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        innerGlow.endPoint = CGPoint(x: 1, y: 1)
        innerGlow.bounds = rect.insetBy(dx: 3, dy: 3)
        innerGlow.transform = CATransform3DTranslate(CATransform3DMakeRotation(.pi / 2, 1, 0, 0), 0, 0, h - 5)
        innerGlow.opacity = 0
        yaw.addSublayer(innerGlow)

        // Lid: hinged along the back-top edge.
        let lidPivot = CATransformLayer()
        lidPivot.transform = CATransform3DMakeTranslation(0, -h, -h)
        yaw.addSublayer(lidPivot)
        lidPivot.addSublayer(lidHinge)
        let lid = CALayer()
        lid.bounds = rect
        lid.anchorPoint = CGPoint(x: 0.5, y: 0)
        lid.contents = lidArt.cgImage
        lid.transform = CATransform3DMakeRotation(.pi / 2, 1, 0, 0)
        lid.isDoubleSided = true
        lid.allowsEdgeAntialiasing = true
        lidHinge.addSublayer(lid)

        // Light beam rising out of the crate (a camera-facing plane through its middle).
        beam.colors = [UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 0).cgColor,
                       UIColor(red: 1, green: 0.9, blue: 0.45, alpha: 0.55).cgColor,
                       UIColor.white.withAlphaComponent(0.95).cgColor]
        beam.locations = [0, 0.6, 1]
        beam.bounds = CGRect(x: 0, y: 0, width: side * 0.92, height: bounds.height * 0.75)
        beam.anchorPoint = CGPoint(x: 0.5, y: 1)
        beam.position = CGPoint(x: center.x, y: center.y - side * 0.34)
        let beamMask = CAGradientLayer()
        beamMask.frame = beam.bounds
        beamMask.startPoint = CGPoint(x: 0, y: 0.5)
        beamMask.endPoint = CGPoint(x: 1, y: 0.5)
        beamMask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
        beamMask.locations = [0, 0.3, 0.7, 1]
        beam.mask = beamMask
        beam.opacity = 0
        layer.addSublayer(beam)

        // Sparks
        emitter.emitterPosition = CGPoint(x: center.x, y: center.y - side * 0.4)
        emitter.emitterSize = CGSize(width: side * 0.7, height: 4)
        emitter.emitterShape = .line
        emitter.renderMode = .additive
        emitter.birthRate = 0
        emitter.emitterCells = [sparkCell(color: amber, speed: side * 4.2, rate: 220),
                                sparkCell(color: .white, speed: side * 5.4, rate: 110)]
        emitter.frame = bounds
        layer.addSublayer(emitter)

        flash.frame = bounds
        flash.backgroundColor = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1).cgColor
        flash.opacity = 0
        layer.addSublayer(flash)

        whiteout.frame = bounds
        whiteout.backgroundColor = UIColor(red: 1, green: 0.96, blue: 0.8, alpha: 1).cgColor
        whiteout.opacity = 0
        layer.addSublayer(whiteout)
    }

    private func sparkCell(color: UIColor, speed: CGFloat, rate: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = CrateArt.sparkImage().cgImage
        cell.birthRate = rate
        cell.lifetime = 1.15
        cell.lifetimeRange = 0.4
        cell.velocity = speed
        cell.velocityRange = speed * 0.5
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 2.6
        cell.yAcceleration = side * 6.5
        cell.scale = 0.42
        cell.scaleRange = 0.3
        cell.scaleSpeed = -0.25
        cell.alphaSpeed = -0.85
        cell.color = color.cgColor
        return cell
    }

    // MARK: - Animation

    private func play() {
        let t0 = CACurrentMediaTime() + 0.05
        CSGOAudioPlayer.shared.playUnbox()

        func key(_ layer: CALayer, _ path: String, values: [Any], times: [Double],
                 start: Double, duration: Double, timing: CAMediaTimingFunctionName = .linear) {
            let a = CAKeyframeAnimation(keyPath: path)
            a.values = values
            a.keyTimes = times.map { NSNumber(value: $0) }
            a.beginTime = t0 + start
            a.duration = duration
            // Later-starting animations must not apply before their start, or
            // they would override an earlier animation on the same key path.
            a.fillMode = start > 0 ? .forwards : .both
            a.isRemovedOnCompletion = false
            a.timingFunction = CAMediaTimingFunction(name: timing)
            layer.add(a, forKey: path + "@\(start)")
        }

        // 1. Drop in from above with a double bounce.
        let dropFrom = -(bounds.height * 0.5 + side * 1.4)
        key(mover, "transform.translation.y",
            values: [dropFrom, 0, -side * 0.2, 0, -side * 0.05, 0],
            times: [0, 0.45, 0.62, 0.78, 0.9, 1], start: 0, duration: 0.7)
        key(floorGlow, "opacity", values: [0, 0.5, 0.5, 1.0], times: [0, 0.2, 0.6, 1],
            start: T.land, duration: T.pop - T.land)

        // 2. Zoom: creep in while it rattles, kick on the pop, then dive.
        key(mover, "transform.scale",
            values: [0.5, 1.0, 1.0, 1.24, 1.42, 1.24, 1.24, 7.4],
            times: [0, 0.10, 0.25, 0.645, 0.67, 0.72, 0.79, 1],
            start: 0, duration: T.end)

        // 3. Rattle: two bursts, each faster and wider than the last.
        var rot: [Any] = [], shiftX: [Any] = [], times: [Double] = []
        let shakeLength = T.pop - T.burst1
        let steps = 64
        var phase = 0.0
        for i in 0...steps {
            let u = Double(i) / Double(steps)
            let t = u * shakeLength
            var amp = 0.0
            if t < T.burst1End - T.burst1 {
                amp = 0.035 + 0.035 * (t / (T.burst1End - T.burst1))
            } else if t >= T.burst2 - T.burst1 {
                let v = (t - (T.burst2 - T.burst1)) / (T.pop - T.burst2)
                amp = 0.05 + 0.15 * v * v
            }
            phase += 1.9 + 1.5 * u
            rot.append(i == steps ? 0 : amp * sin(phase))
            shiftX.append(i == steps ? 0 : amp * Double(side) * 0.9 * sin(phase * 1.31 + 1))
            times.append(u)
        }
        key(mover, "transform.rotation.z", values: rot, times: times, start: T.burst1, duration: shakeLength)
        key(mover, "transform.translation.x", values: shiftX, times: times, start: T.burst1, duration: shakeLength)

        // Slow turn while it rattles; square up and tip forward for the dive.
        key(yaw, "transform.rotation.y", values: [1.05, 0.62, 0.62, 0.0], times: [0, 0.6, 0.79, 1],
            start: 0, duration: T.end, timing: .easeOut)
        key(tilt, "transform.rotation.x", values: [-0.44, -0.44, -1.12], times: [0, 0.2, 1],
            start: T.dive - 0.15, duration: T.end - T.dive + 0.15, timing: .easeIn)
        key(mover, "transform.translation.y", values: [0, side * 1.9], times: [0, 1],
            start: T.dive, duration: T.end - T.dive, timing: .easeIn)

        // 4. Light leaking from the seams and the lid chattering before it blows.
        for s in seams {
            key(s, "opacity", values: [0, 0.5, 0.15, 0.2, 0.9, 0.6, 1.0],
                times: [0, 0.22, 0.3, 0.42, 0.7, 0.8, 1], start: T.burst1, duration: shakeLength)
        }
        key(lidHinge, "transform.rotation.x",
            values: [0, 0.06, 0, 0.10, 0.01, 0.16, 0.03, 0.22, 0.05],
            times: [0, 0.12, 0.24, 0.38, 0.5, 0.64, 0.76, 0.9, 1],
            start: T.burst2, duration: T.pop - T.burst2)
        key(innerGlow, "opacity", values: [0, 0.75], times: [0, 1], start: T.burst2, duration: T.pop - T.burst2)

        // 5. The pop: lid flies back, beam, flash, sparks.
        key(lidHinge, "transform.rotation.x", values: [0.05, 2.35, 1.95, 2.1],
            times: [0, 0.5, 0.78, 1], start: T.pop, duration: 0.42, timing: .easeOut)
        key(innerGlow, "opacity", values: [0.75, 1], times: [0, 1], start: T.pop, duration: 0.1)
        key(beam, "opacity", values: [0, 1, 0.85], times: [0, 0.4, 1], start: T.pop, duration: 0.35)
        key(beam, "transform.scale.y", values: [0.05, 1.0], times: [0, 1], start: T.pop, duration: 0.3, timing: .easeOut)
        key(beam, "opacity", values: [0.85, 0], times: [0, 1], start: T.dive, duration: 0.3)
        key(flash, "opacity", values: [0, 0.8, 0], times: [0, 0.18, 1], start: T.pop, duration: 0.45)

        // 6. White-out into the reel.
        key(whiteout, "opacity", values: [0, 1], times: [0, 1], start: T.end - 0.38, duration: 0.33, timing: .easeIn)

        scheduleHaptics()

        after(T.pop) { [weak self] in self?.emitter.birthRate = 1 }
        after(T.pop + 0.28) { [weak self] in self?.emitter.birthRate = 0 }
        after(T.end) { [weak self] in self?.onFinished?() }
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 + seconds, execute: work)
    }

    private func scheduleHaptics() {
        let light = UIImpactFeedbackGenerator(style: .light)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()

        after(T.land) { heavy.impactOccurred() }
        after(T.land + 0.21) { medium.impactOccurred(intensity: 0.6) }

        var t = T.burst1
        while t < T.burst1End { let at = t; after(at) { light.impactOccurred() }; t += 0.07 }

        t = T.burst2
        var gap = 0.085
        while t < T.pop - 0.03 {
            let at = t
            let strength = CGFloat((at - T.burst2) / (T.pop - T.burst2))
            after(at) {
                if strength > 0.55 { heavy.impactOccurred(intensity: 0.5 + 0.5 * strength) }
                else { medium.impactOccurred(intensity: 0.5 + strength) }
            }
            t += gap
            gap = max(0.04, gap * 0.9)
        }

        after(T.pop) {
            heavy.impactOccurred(intensity: 1)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Crate textures

enum CrateArt {

    enum Kind { case front, side, lid, plain }

    static func sparkImage() -> UIImage {
        let size = CGSize(width: 28, height: 28)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 14, y: 14), startRadius: 0,
                                             endCenter: CGPoint(x: 14, y: 14), endRadius: 14, options: [])
        }
    }

    /// One face of the crate: gunmetal plate, amber frame, bolts and markings.
    /// `shade` fakes directional lighting (1 = lit, lower = in shadow).
    static func face(side: CGFloat, kind: Kind, shade: CGFloat) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let amber = UIColor(red: min(1, 1.0 * shade), green: min(1, 0.78 * shade), blue: 0.10 * shade, alpha: 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true

        return UIGraphicsImageRenderer(size: rect.size, format: format).image { rc in
            let ctx = rc.cgContext

            // Plate
            let top = UIColor(red: 0.21 * shade, green: 0.23 * shade, blue: 0.31 * shade, alpha: 1)
            let bot = UIColor(red: 0.08 * shade, green: 0.09 * shade, blue: 0.13 * shade, alpha: 1)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [top.cgColor, bot.cgColor] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side * 0.25, y: side), options: [])

            // Recessed inner panel
            let panel = rect.insetBy(dx: side * 0.11, dy: side * 0.11)
            UIColor(white: 0, alpha: 0.28).setFill()
            UIBezierPath(roundedRect: panel, cornerRadius: side * 0.035).fill()
            UIColor(white: 1, alpha: 0.07 * shade).setStroke()
            let panelEdge = UIBezierPath(roundedRect: panel, cornerRadius: side * 0.035)
            panelEdge.lineWidth = 1.5
            panelEdge.stroke()

            if kind == .front || kind == .side {
                // Hazard band across the lower part of the panel
                let band = CGRect(x: panel.minX, y: panel.maxY - side * 0.2, width: panel.width, height: side * 0.12)
                ctx.saveGState()
                UIBezierPath(rect: band).addClip()
                UIColor(white: 0.03, alpha: 1).setFill()
                ctx.fill(band)
                amber.setFill()
                let stripe = side * 0.075
                var x = band.minX - band.height
                while x < band.maxX {
                    let p = UIBezierPath()
                    p.move(to: CGPoint(x: x, y: band.maxY))
                    p.addLine(to: CGPoint(x: x + band.height, y: band.minY))
                    p.addLine(to: CGPoint(x: x + band.height + stripe, y: band.minY))
                    p.addLine(to: CGPoint(x: x + stripe, y: band.maxY))
                    p.close()
                    p.fill()
                    x += stripe * 2
                }
                ctx.restoreGState()
            }

            switch kind {
            case .front:
                let cfg = UIImage.SymbolConfiguration(pointSize: side * 0.3, weight: .black)
                if let symbol = UIImage(systemName: "shippingbox.fill", withConfiguration: cfg)?
                    .withTintColor(amber, renderingMode: .alwaysOriginal) {
                    let s = symbol.size
                    symbol.draw(at: CGPoint(x: rect.midX - s.width / 2, y: side * 0.33 - s.height / 2))
                }
                drawText("APP UNBOXED", size: side * 0.082, color: .white.withAlphaComponent(0.92 * shade),
                         center: CGPoint(x: rect.midX, y: side * 0.585), kern: side * 0.008)
            case .side:
                drawText("?", size: side * 0.5, color: amber, center: CGPoint(x: rect.midX, y: side * 0.38), kern: 0)
            case .lid:
                let plate = CGRect(x: rect.midX - side * 0.27, y: rect.midY - side * 0.1, width: side * 0.54, height: side * 0.2)
                UIColor(white: 0.03, alpha: 0.75).setFill()
                UIBezierPath(roundedRect: plate, cornerRadius: side * 0.03).fill()
                amber.setStroke()
                let edge = UIBezierPath(roundedRect: plate, cornerRadius: side * 0.03)
                edge.lineWidth = 2
                edge.stroke()
                drawText("DUO CASE", size: side * 0.085, color: amber, center: CGPoint(x: rect.midX, y: rect.midY), kern: side * 0.01)
            case .plain:
                break
            }

            // Amber frame + corner bolts
            amber.setStroke()
            let frame = UIBezierPath(rect: rect.insetBy(dx: side * 0.02, dy: side * 0.02))
            frame.lineWidth = side * 0.04
            frame.stroke()
            UIColor(white: 1, alpha: 0.35 * shade).setStroke()
            let highlight = UIBezierPath()
            highlight.move(to: CGPoint(x: side * 0.045, y: side * 0.045))
            highlight.addLine(to: CGPoint(x: side * 0.955, y: side * 0.045))
            highlight.lineWidth = 1.5
            highlight.stroke()

            let inset = side * 0.075
            for c in [CGPoint(x: inset, y: inset), CGPoint(x: side - inset, y: inset),
                      CGPoint(x: inset, y: side - inset), CGPoint(x: side - inset, y: side - inset)] {
                let r = side * 0.022
                UIColor(white: 0.75 * shade, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
                UIColor(white: 0.1, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - r * 0.4, y: c.y - r * 0.4, width: r * 0.8, height: r * 0.8)).fill()
            }
        }
    }

    private static func drawText(_ text: String, size: CGFloat, color: UIColor, center: CGPoint, kern: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .black),
            .foregroundColor: color,
            .kern: kern,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let s = str.size()
        str.draw(at: CGPoint(x: center.x - s.width / 2, y: center.y - s.height / 2))
    }
}
