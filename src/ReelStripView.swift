import SwiftUI
import UIKit

/// Drives the reel from SwiftUI. The strip itself is plain Core Animation
/// layers, so the roll runs on the render server and stays smooth even when
/// the main thread is busy (the old SwiftUI strip re-rendered 70 cards on
/// every tick, which is what made the start of the spin stutter).
final class ReelController: ObservableObject {

    fileprivate weak var view: ReelStripView?
    fileprivate var items: [AppEntry] = []
    fileprivate var position: CGFloat = 3

    func load(items: [AppEntry], position: CGFloat) {
        self.items = items
        self.position = position
        view?.reload()
    }

    func roll(to target: CGFloat, duration: Double, curve: (Double, Double, Double, Double)) {
        let from = position
        position = target
        view?.roll(from: from, to: target, duration: duration, curve: curve)
    }

    func land(on index: Int, accent: UIColor) {
        position = CGFloat(index)
        view?.land(on: index, accent: accent)
    }

    func tick() { view?.pulseMarker() }
}

struct ReelStrip: UIViewRepresentable {
    let controller: ReelController
    let cardSize: CGSize
    let spacing: CGFloat

    func makeUIView(context: Context) -> ReelStripView {
        let view = ReelStripView()
        view.controller = controller
        controller.view = view
        view.configure(cardSize: cardSize, spacing: spacing)
        return view
    }

    func updateUIView(_ view: ReelStripView, context: Context) {
        view.configure(cardSize: cardSize, spacing: spacing)
    }
}

final class ReelStripView: UIView {

    weak var controller: ReelController?

    private var cardSize = CGSize(width: 200, height: 260)
    private var spacing: CGFloat = 14
    private var step: CGFloat { cardSize.width + spacing }

    private let strip = CALayer()
    private var cards: [CALayer] = []
    private let stripHolder = CALayer()
    private let edgeMask = CAGradientLayer()
    private let marker = CAShapeLayer()
    private var laidOutWidth: CGFloat = 0

    private static let amber = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true

        // The strip lives in a holder whose mask fades both edges to nothing,
        // so whatever is behind the reel shows through cleanly.
        strip.anchorPoint = CGPoint(x: 0, y: 0.5)
        stripHolder.addSublayer(strip)
        edgeMask.startPoint = CGPoint(x: 0, y: 0.5)
        edgeMask.endPoint = CGPoint(x: 1, y: 0.5)
        edgeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        edgeMask.locations = [0, 0.17, 0.83, 1]
        stripHolder.mask = edgeMask
        layer.addSublayer(stripHolder)

        marker.fillColor = Self.amber.cgColor
        marker.shadowColor = Self.amber.cgColor
        marker.shadowOpacity = 1
        marker.shadowRadius = 8
        marker.shadowOffset = .zero
        layer.addSublayer(marker)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(cardSize: CGSize, spacing: CGFloat) {
        guard cardSize != self.cardSize || spacing != self.spacing || cards.isEmpty else { return }
        self.cardSize = cardSize
        self.spacing = spacing
        reload()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width != laidOutWidth else { return }
        laidOutWidth = bounds.width
        layoutChrome()
        placeStrip(at: controller?.position ?? 3)
    }

    // MARK: Build

    func reload() {
        guard let controller = controller else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.removeAllAnimations()
        cards.forEach { $0.removeFromSuperlayer() }
        cards = controller.items.enumerated().map { index, app in
            let card = ReelCard.layer(for: app, size: cardSize)
            card.position = CGPoint(x: CGFloat(index) * step + cardSize.width / 2, y: 0)
            strip.addSublayer(card)
            return card
        }
        strip.bounds = CGRect(x: 0, y: -cardSize.height / 2,
                              width: CGFloat(max(cards.count, 1)) * step, height: cardSize.height)
        marker.opacity = 1
        setAccent(Self.amber)
        layoutChrome()
        placeStrip(at: controller.position)
        CATransaction.commit()
    }

    private func layoutChrome() {
        stripHolder.frame = bounds
        edgeMask.frame = stripHolder.bounds

        // Thin line with a small arrow head at each end.
        let h = min(bounds.height, cardSize.height * 1.3 + 30)
        let top = bounds.midY - h / 2, bottom = bounds.midY + h / 2
        let x = bounds.midX
        let path = UIBezierPath(rect: CGRect(x: x - 1.25, y: top + 12, width: 2.5, height: h - 24))
        path.move(to: CGPoint(x: x - 9, y: top)); path.addLine(to: CGPoint(x: x + 9, y: top))
        path.addLine(to: CGPoint(x: x, y: top + 14)); path.close()
        path.move(to: CGPoint(x: x - 9, y: bottom)); path.addLine(to: CGPoint(x: x + 9, y: bottom))
        path.addLine(to: CGPoint(x: x, y: bottom - 14)); path.close()
        marker.frame = bounds
        marker.path = path.cgPath
    }

    private func stripX(for position: CGFloat) -> CGFloat {
        bounds.midX - (position * step + cardSize.width / 2)
    }

    private func placeStrip(at position: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.position = CGPoint(x: stripX(for: position), y: bounds.midY)
        CATransaction.commit()
    }

    private func setAccent(_ color: UIColor) {
        marker.fillColor = color.cgColor
        marker.shadowColor = color.cgColor
    }

    // MARK: Motion

    func roll(from: CGFloat, to: CGFloat, duration: Double, curve: (Double, Double, Double, Double)) {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = stripX(for: from)
        animation.toValue = stripX(for: to)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints: Float(curve.0), Float(curve.1),
                                                         Float(curve.2), Float(curve.3))
        placeStrip(at: to)
        strip.add(animation, forKey: "roll")
    }

    func land(on index: Int, accent: UIColor) {
        // Settle from the off-centre stop onto dead centre.
        let settle = CASpringAnimation(keyPath: "position.x")
        settle.fromValue = strip.presentation()?.position.x ?? strip.position.x
        settle.toValue = stripX(for: CGFloat(index))
        settle.damping = 16
        settle.stiffness = 170
        settle.mass = 1
        settle.duration = settle.settlingDuration
        placeStrip(at: CGFloat(index))
        strip.add(settle, forKey: "settle")

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.35)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        marker.opacity = 0
        for (i, card) in cards.enumerated() where i != index { card.opacity = 0.3 }
        CATransaction.commit()

        guard cards.indices.contains(index) else { return }
        let winner = cards[index]
        winner.zPosition = 10
        winner.borderColor = accent.withAlphaComponent(0.9).cgColor
        winner.borderWidth = 2
        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 1.0
        pop.toValue = 1.1
        pop.damping = 11
        pop.stiffness = 190
        pop.duration = pop.settlingDuration
        winner.transform = CATransform3DMakeScale(1.1, 1.1, 1)
        winner.add(pop, forKey: "pop")
    }

    func pulseMarker() {
        let pulse = CABasicAnimation(keyPath: "transform.scale.y")
        pulse.fromValue = 1.035
        pulse.toValue = 1.0
        pulse.duration = 0.09
        marker.add(pulse, forKey: "pulse")
    }
}

// MARK: - Card layers

enum ReelCard {

    private static var iconCache: [String: CGImage] = [:]

    /// One card: dark plate lit from below in the rarity colour, the app's
    /// icon and its name. Rasterised once, then moved as a single texture.
    static func layer(for app: AppEntry, size: CGSize) -> CALayer {
        let scale = UIScreen.main.scale
        let tint = app.color
        let card = CALayer()
        card.bounds = CGRect(origin: .zero, size: size)
        card.cornerRadius = size.width * 0.085
        card.cornerCurve = .continuous
        card.masksToBounds = true
        card.backgroundColor = UIColor(red: 0.075, green: 0.082, blue: 0.115, alpha: 1).cgColor
        card.borderColor = UIColor(white: 1, alpha: 0.07).cgColor
        card.borderWidth = 1

        let glow = CAGradientLayer()
        glow.frame = card.bounds
        glow.colors = [tint.withAlphaComponent(0).cgColor, tint.withAlphaComponent(0.36).cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 0.5, y: 1)
        card.addSublayer(glow)

        let bar = CALayer()
        bar.frame = CGRect(x: 0, y: size.height - 4, width: size.width, height: 4)
        bar.backgroundColor = tint.cgColor
        card.addSublayer(bar)

        let iconSide = size.width * 0.56
        let fontSize = max(12, size.width * 0.085)
        let gap = size.height * 0.07
        let blockHeight = iconSide + gap + fontSize * 1.3
        let top = (size.height - blockHeight) / 2

        let icon = CALayer()
        icon.frame = CGRect(x: (size.width - iconSide) / 2, y: top, width: iconSide, height: iconSide)
        icon.contents = iconImage(for: app, side: iconSide, scale: scale)
        icon.contentsScale = scale
        card.addSublayer(icon)

        let label = CATextLayer()
        var font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        if let rounded = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: rounded, size: fontSize)
        }
        label.font = font
        label.fontSize = fontSize
        label.string = app.name
        label.foregroundColor = UIColor.white.cgColor
        label.alignmentMode = .center
        label.truncationMode = .end
        label.contentsScale = scale
        label.frame = CGRect(x: 10, y: top + iconSide + gap, width: size.width - 20, height: fontSize * 1.35)
        card.addSublayer(label)

        card.shouldRasterize = true
        card.rasterizationScale = scale
        return card
    }

    /// The real icon clipped to the iOS icon shape, or a symbol tile fallback.
    private static func iconImage(for app: AppEntry, side: CGFloat, scale: CGFloat) -> CGImage? {
        let key = "\(app.id)@\(Int(side))@\(app.icon != nil)"
        if let cached = iconCache[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            let shape = UIBezierPath(roundedRect: rect, cornerRadius: side * 0.225)
            if let real = app.icon {
                shape.addClip()
                real.draw(in: rect)
            } else {
                app.color.withAlphaComponent(0.22).setFill()
                shape.fill()
                app.color.setStroke()
                let edge = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: side * 0.225)
                edge.lineWidth = 2
                edge.stroke()
                let cfg = UIImage.SymbolConfiguration(pointSize: side * 0.46, weight: .semibold)
                if let symbol = (UIImage(systemName: app.systemIcon, withConfiguration: cfg)
                                 ?? UIImage(systemName: "app.fill", withConfiguration: cfg))?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let s = symbol.size
                    symbol.draw(at: CGPoint(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2))
                }
            }
        }.cgImage
        if iconCache.count > 400 { iconCache.removeAll() }
        iconCache[key] = image
        return image
    }
}
