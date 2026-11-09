import Foundation
import UIKit
import Combine

public class DuoHingeSensor: ObservableObject {
    public static let shared = DuoHingeSensor()

    // Default to true (Folded Cover Screen) when starting on a phone
    @Published public var isFolded: Bool = true
    @Published public var sensorStatus: String = "DUO SENSOR ARMED"
    @Published public var displayMetrics: String = "Detecting Display..."

    public var onUnfoldAndRoll: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var isInitialEvaluationDone: Bool = false
    private var previousWidth: CGFloat = 0.0
    private var previousHeight: CGFloat = 0.0
    private var previousMinDim: CGFloat = 0.0
    private var previousMaxDim: CGFloat = 0.0
    private var previousArea: CGFloat = 0.0
    private var lastTriggerTime: Date = Date.distantPast
    private var lastEvaluatedSize: CGSize = .zero

    private init() {
        setupHardwareListeners()
    }

    private func setupHardwareListeners() {
        // Darwin / Jailbreak Hinge Notifications (Zero false triggers from touch/proximity)
        let notifs = [
            "com.apple.springboard.hasUnfolded",
            "com.apple.springboard.hingeAngle",
            "com.microsoft.surfaceduo.hinge",
            "AppUnboxedTriggerSpinNotification"
        ]

        for name in notifs {
            NotificationCenter.default.publisher(for: Notification.Name(name))
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.isFolded = false
                    self.sensorStatus = "Hardware Hinge Signal: Duo Unfolded!"
                    self.triggerRoll()
                }
                .store(in: &cancellables)
        }
    }

    /// Evaluates display geometry with strict mathematical rotation invariance.
    /// In pure rotation: min(W, H), max(W, H), and Area are invariant (delta ≈ 0).
    /// In hardware unfolding: Area doubles and min(W, H) expands by > 120pt.
    public func evaluateGeometry(width: CGFloat, height: CGFloat) {
        guard width > 80 && height > 80 else { return }

        // Ignore repeat reports of the same size. Every @Published write makes
        // SwiftUI re-render, which lays out again and reports the same size
        // back here; without this guard that cycle never ends and the main
        // thread spins at 100% CPU with nothing drawn (the black-screen bug).
        let size = CGSize(width: width, height: height)
        guard size != lastEvaluatedSize else { return }
        lastEvaluatedSize = size

        let currentMin = min(width, height)
        let currentMax = max(width, height)
        let currentArea = width * height
        let metrics = "\(Int(width))×\(Int(height)) pt (Min: \(Int(currentMin)))"
        if displayMetrics != metrics { displayMetrics = metrics }

        // First initial layout pass
        if !isInitialEvaluationDone {
            isInitialEvaluationDone = true
            previousWidth = width
            previousHeight = height
            previousMinDim = currentMin
            previousMaxDim = currentMax
            previousArea = currentArea

            // Determine if the app launched on a wide unfolded dual-screen canvas or folded phone
            if currentMin >= 550.0 || (width > height && width > 600.0) {
                self.isFolded = false
                self.sensorStatus = "Duo 2-Screen Unfolded (Initial Launch)"
            } else {
                self.isFolded = true
                self.sensorStatus = "Duo 1-Screen Folded (Cover Display)"
            }
            return
        }

        // Calculate differences from previous recorded layout
        let minDelta = abs(currentMin - previousMinDim)
        let maxDelta = abs(currentMax - previousMaxDim)
        let areaRatio = currentArea / max(1.0, previousArea)

        // -------------------------------------------------------------
        // CHECK 1: PORTRAIT <-> LANDSCAPE ROTATION WHILE FOLDED OR OPEN
        // -------------------------------------------------------------
        // Rotating the device simply swaps width and height.
        // min(W, H), max(W, H), and Area change by less than 45 points / 15%.
        if minDelta < 45.0 && maxDelta < 45.0 && (areaRatio > 0.82 && areaRatio < 1.18) {
            // ROTATION CONFIRMED: DO NOT CHANGE FOLDED STATE, DO NOT TRIGGER ROLL!
            let orientation = width > height ? "Landscape" : "Portrait"
            if isFolded {
                self.sensorStatus = "Cover Display (\(orientation))"
            } else {
                self.sensorStatus = "2 Inner Screens (\(orientation))"
            }
            previousWidth = width
            previousHeight = height
            return
        }

        // -------------------------------------------------------------
        // CHECK 2: PHYSICAL HARDWARE DISPLAY UNFOLD (Expanded Canvas)
        // -------------------------------------------------------------
        // When spanned across 2 screens: Area grows by ≥ 35% or min dimension jumps > 100pt.
        if isFolded {
            let isAreaExpanded = areaRatio >= 1.35
            let isMinDimExpanded = (currentMin - previousMinDim) > 100.0 || currentMin >= 550.0

            if isAreaExpanded || isMinDimExpanded {
                self.isFolded = false
                self.sensorStatus = "Duo Unfolded! Case Rolling..."
                triggerRoll()
            }
        }
        // -------------------------------------------------------------
        // CHECK 3: PHYSICAL HARDWARE DISPLAY FOLD (Contracted Canvas)
        // -------------------------------------------------------------
        else if !isFolded {
            let isAreaContracted = areaRatio <= 0.72
            let isMinDimContracted = (previousMinDim - currentMin) > 100.0 && currentMin < 550.0

            if isAreaContracted || isMinDimContracted {
                self.isFolded = true
                self.sensorStatus = "Duo Folded (Cover Display)"
            }
        }

        // Record dimensions for next layout pass
        previousWidth = width
        previousHeight = height
        previousMinDim = currentMin
        previousMaxDim = currentMax
        previousArea = currentArea
    }

    /// Manual user override for immediate testing
    public func setFoldedState(_ folded: Bool) {
        self.isFolded = folded
        self.sensorStatus = folded ? "Cover Display (1 Screen)" : "2 Inner Screens (Unfolded)"
        if !folded {
            triggerRoll()
        }
    }

    /// Triggers the unboxing roll with a debounce to prevent double-spins
    public func triggerRoll() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > 1.0 else { return }
        lastTriggerTime = now

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.onUnfoldAndRoll?()
        }
    }
}
