import SwiftUI
import UIKit

/// The idle loot box on the cover screen: a real 3D crate that turns slowly,
/// floats, and every few seconds rattles while its lid chatters and gold light
/// and motes leak out. Everything loops until the phone is opened.
struct CoverCrate: UIViewRepresentable {
    func makeUIView(context: Context) -> CoverCrateView { CoverCrateView() }
    func updateUIView(_ uiView: CoverCrateView, context: Context) {}
}

final class CoverCrateView: UIView {

    private let gold = UIColor(red: 1.0, green: 0.80, blue: 0.16, alpha: 1)

    private let halo = CAGradientLayer()
    private let floorGlow = CAGradientLayer()
    private let beam = CAGradientLayer()
    private let perspective = CALayer()
    private let mover = CATransformLayer()
    private let tilt = CATransformLayer()
    private let yaw = CATransformLayer()
    private let lidHinge = CATransformLayer()
    private let innerGlow = CAGradientLayer()
    private let emitter = CAEmitterLayer()
    private var seams: [CALayer] = []
    private var builtSide: CGFloat = 0
    private var side: CGFloat = 150

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        // Core Animation drops running animations when the app is backgrounded.
        NotificationCenter.default.addObserver(self, selector: #selector(restart),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 40, bounds.height > 40 else { return }
        let wanted = (min(bounds.width, bounds.height) * 0.40).rounded()
        guard abs(wanted - builtSide) > 1 else { return }
        builtSide = wanted
        side = wanted
        build()
        animate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, builtSide > 0 { animate() }
    }

    @objc private func restart() {
        if window != nil, builtSide > 0 { animate() }
    }

    // MARK: Scene

    private func build() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        seams.removeAll()
        [mover, tilt, yaw, lidHinge].forEach { $0.sublayers?.forEach { $0.removeFromSuperlayer() } }

        let center = CGPoint(x: bounds.midX, y: bounds.midY + side * 0.05)

        // Gold aura behind the crate.
        halo.type = .radial
        halo.colors = [gold.withAlphaComponent(0.34).cgColor, gold.withAlphaComponent(0.08).cgColor,
                       gold.withAlphaComponent(0).cgColor]
        halo.locations = [0, 0.5, 1]
        halo.startPoint = CGPoint(x: 0.5, y: 0.5)
        halo.endPoint = CGPoint(x: 1, y: 1)
        halo.bounds = CGRect(x: 0, y: 0, width: side * 3.0, height: side * 3.0)
        halo.position = CGPoint(x: center.x, y: center.y - side * 0.1)
        layer.addSublayer(halo)

        floorGlow.type = .radial
        floorGlow.colors = [gold.withAlphaComponent(0.5).cgColor, gold.withAlphaComponent(0).cgColor]
        floorGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        floorGlow.endPoint = CGPoint(x: 1, y: 1)
        floorGlow.bounds = CGRect(x: 0, y: 0, width: side * 2.6, height: side * 0.6)
        floorGlow.position = CGPoint(x: center.x, y: center.y + side * 1.02)
        layer.addSublayer(floorGlow)

        // Faint shaft of light above the lid; flares when the lid chatters.
        beam.colors = [gold.withAlphaComponent(0).cgColor, UIColor(red: 1, green: 0.93, blue: 0.6, alpha: 0.55).cgColor]
        beam.bounds = CGRect(x: 0, y: 0, width: side * 0.8, height: side * 1.5)
        beam.anchorPoint = CGPoint(x: 0.5, y: 1)
        beam.position = CGPoint(x: center.x, y: center.y - side * 0.38)
        let beamMask = CAGradientLayer()
        beamMask.frame = beam.bounds
        beamMask.startPoint = CGPoint(x: 0, y: 0.5)
        beamMask.endPoint = CGPoint(x: 1, y: 0.5)
        beamMask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
        beam.mask = beamMask
        beam.opacity = 0
        layer.addSublayer(beam)

        perspective.frame = bounds
        var p = CATransform3DIdentity
        p.m34 = -1.0 / (side * 5.2)
        perspective.sublayerTransform = p
        layer.addSublayer(perspective)

        mover.position = center
        perspective.addSublayer(mover)
        tilt.transform = CATransform3DMakeRotation(-0.40, 1, 0, 0)
        mover.addSublayer(tilt)
        tilt.addSublayer(yaw)

        let h = side / 2
        let rect = CGRect(x: 0, y: 0, width: side, height: side)

        func face(_ image: UIImage, _ transform: CATransform3D) {
            let f = CALayer()
            f.bounds = rect
            f.contents = image.cgImage
            f.transform = transform
            f.isDoubleSided = true
            f.allowsEdgeAntialiasing = true
            yaw.addSublayer(f)
            // Gold light leaking along the top seam of each side.
            let s = CALayer()
            s.frame = CGRect(x: 4, y: -2, width: side - 8, height: 5)
            s.backgroundColor = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1).cgColor
            s.shadowColor = gold.cgColor
            s.shadowRadius = 12
            s.shadowOpacity = 1
            s.shadowOffset = .zero
            s.opacity = 0.4
            f.addSublayer(s)
            seams.append(s)
        }

        // The crate turns a full circle, so every side is a "lit" face.
        let front = CrateArt.face(side: side, kind: .front, shade: 1.0)
        let sideArt = CrateArt.face(side: side, kind: .side, shade: 0.85)
        let bottom = CrateArt.face(side: side, kind: .plain, shade: 0.35)
        let lidArt = CrateArt.face(side: side, kind: .lid, shade: 1.22)

        face(front, CATransform3DMakeTranslation(0, 0, h))
        face(front, CATransform3DTranslate(CATransform3DMakeRotation(.pi, 0, 1, 0), 0, 0, h))
        face(sideArt, CATransform3DTranslate(CATransform3DMakeRotation(.pi / 2, 0, 1, 0), 0, 0, h))
        face(sideArt, CATransform3DTranslate(CATransform3DMakeRotation(-.pi / 2, 0, 1, 0), 0, 0, h))
        let floor = CALayer()
        floor.bounds = rect
        floor.contents = bottom.cgImage
        floor.transform = CATransform3DTranslate(CATransform3DMakeRotation(-.pi / 2, 1, 0, 0), 0, 0, h)
        yaw.addSublayer(floor)

        innerGlow.type = .radial
        innerGlow.colors = [UIColor.white.cgColor,
                            UIColor(red: 1, green: 0.92, blue: 0.45, alpha: 1).cgColor,
                            UIColor(red: 1, green: 0.62, blue: 0.05, alpha: 1).cgColor]
        innerGlow.locations = [0, 0.45, 1]
        innerGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        innerGlow.endPoint = CGPoint(x: 1, y: 1)
        innerGlow.bounds = rect.insetBy(dx: 3, dy: 3)
        innerGlow.transform = CATransform3DTranslate(CATransform3DMakeRotation(.pi / 2, 1, 0, 0), 0, 0, h - 5)
        yaw.addSublayer(innerGlow)

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

        // Gold motes drifting up out of the crate.
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: center.x, y: center.y - side * 0.42)
        emitter.emitterSize = CGSize(width: side * 0.75, height: 6)
        emitter.emitterShape = .line
        emitter.renderMode = .additive
        let mote = CAEmitterCell()
        mote.contents = CrateArt.sparkImage().cgImage
        mote.birthRate = 16
        mote.lifetime = 2.6
        mote.lifetimeRange = 0.9
        mote.velocity = side * 0.42
        mote.velocityRange = side * 0.25
        mote.emissionLongitude = -.pi / 2
        mote.emissionRange = .pi / 5
        mote.yAcceleration = -side * 0.08
        mote.scale = 0.2
        mote.scaleRange = 0.14
        mote.alphaSpeed = -0.38
        mote.color = gold.cgColor
        emitter.emitterCells = [mote]
        layer.addSublayer(emitter)
    }

    // MARK: Looping animation

    private func animate() {
        [mover, yaw, lidHinge, innerGlow, beam, halo, floorGlow].forEach { $0.removeAllAnimations() }
        seams.forEach { $0.removeAllAnimations() }

        func loop(_ layer: CALayer, _ path: String, values: [Any], times: [Double], duration: Double,
                  timing: CAMediaTimingFunctionName = .linear) {
            let a = CAKeyframeAnimation(keyPath: path)
            a.values = values
            a.keyTimes = times.map { NSNumber(value: $0) }
            a.duration = duration
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: timing)
            a.isRemovedOnCompletion = false
            layer.add(a, forKey: path)
        }

        // Slow full turn + gentle float.
        loop(yaw, "transform.rotation.y", values: [0.5, 0.5 + 2 * Double.pi], times: [0, 1], duration: 10)
        loop(mover, "transform.translation.y", values: [0, -side * 0.07, 0], times: [0, 0.5, 1],
             duration: 2.8, timing: .easeInEaseOut)

        // Every 3.6 s: a rattle while the lid chatters and gold light spills out.
        let cycle = 3.6
        var rot: [Any] = [0], shift: [Any] = [0], times: [Double] = [0]
        let burstStart = 0.62, burstEnd = 0.90
        let steps = 22
        for i in 0...steps {
            let u = Double(i) / Double(steps)
            let envelope = sin(u * Double.pi)                 // swell and fade
            let phase = Double(i) * 2.3
            rot.append(0.085 * envelope * sin(phase))
            shift.append(Double(side) * 0.05 * envelope * sin(phase * 1.3 + 1))
            times.append(burstStart + (burstEnd - burstStart) * u)
        }
        rot.append(0); shift.append(0); times.append(1)
        loop(mover, "transform.rotation.z", values: rot, times: times, duration: cycle)
        loop(mover, "transform.translation.x", values: shift, times: times, duration: cycle)

        loop(lidHinge, "transform.rotation.x",
             values: [0, 0, 0.10, 0.02, 0.20, 0.05, 0.26, 0.04, 0.12, 0, 0],
             times: [0, 0.62, 0.66, 0.70, 0.74, 0.78, 0.82, 0.86, 0.89, 0.93, 1], duration: cycle)
        loop(innerGlow, "opacity", values: [0.35, 0.35, 1.0, 1.0, 0.35, 0.35],
             times: [0, 0.60, 0.70, 0.86, 0.95, 1], duration: cycle)
        loop(beam, "opacity", values: [0, 0, 0.9, 0.6, 0.95, 0, 0],
             times: [0, 0.62, 0.72, 0.78, 0.84, 0.94, 1], duration: cycle)
        loop(halo, "opacity", values: [0.7, 0.7, 1.0, 1.0, 0.7, 0.7],
             times: [0, 0.60, 0.72, 0.86, 0.96, 1], duration: cycle)
        loop(floorGlow, "opacity", values: [0.55, 0.9, 0.55], times: [0, 0.5, 1], duration: 2.8, timing: .easeInEaseOut)

        for (i, s) in seams.enumerated() {
            loop(s, "opacity", values: [0.3, 0.95, 0.3], times: [0, 0.5, 1],
                 duration: 1.5 + Double(i) * 0.17, timing: .easeInEaseOut)
        }
    }
}
