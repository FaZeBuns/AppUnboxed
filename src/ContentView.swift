import SwiftUI
import AudioToolbox

public struct ContentView: View {
    @StateObject private var appsModel = InstalledAppsModel()
    @StateObject private var hinge = DuoHingeSensor.shared
    @StateObject private var reel = ReelController()

    @State private var reelItems: [AppEntry] = []
    @State private var isSpinning: Bool = false
    @State private var scrollTargetID: String? = nil
    @State private var winningApp: AppEntry? = nil
    @State private var statusText: String = "DUO CONTAINER #1 // READY"
    @State private var needleDeflect: Bool = false
    @State private var showWinnerBanner: Bool = false
    @State private var pulseGlow: Bool = false
    @State private var showCrate: Bool = false
    @State private var reelPosition: CGFloat = 3      // which card sits under the marker
    @State private var landed: Bool = false
    @State private var showAddApps: Bool = false
    @State private var pendingUnbox: Bool = false
    @State private var isGoldSequence: Bool = false
    @State private var isGoldSecondSpin: Bool = false
    @State private var finalGoldWinner: AppEntry? = nil
    @State private var forceGoldNext: Bool = false
    @State private var titleTapCount: Int = 0

    let totalReelCards = 70
    let winnerTargetIndex = 54

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pitch Black True OLED Background — Fills 100% of Screen Edge-to-Edge
                Color.black
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // TOP HARDWARE BAR (Live Status + Mode Toggle)

                    // MAIN VIEWPORT: Sleek Folded Cover vs 2-Inner-Screen CS:GO Reel
                    if hinge.isFolded {
                        foldedCoverView(width: geo.size.width, height: geo.size.height)
                    } else {
                        unfoldedDualScreenView(width: geo.size.width, height: geo.size.height)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .edgesIgnoringSafeArea(.all)

                // 3D crate cinematic that plays before every spin
                if showCrate {
                    CrateOpeningView(onFinished: {
                        withAnimation(.easeOut(duration: 0.3)) { showCrate = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { startRoll() }
                    })
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                generateReel()
                hinge.onUnfoldAndRoll = {
                    beginUnbox()
                }
                hinge.evaluateGeometry(width: geo.size.width, height: geo.size.height)

                // Only auto-roll on launch if already unfolded across 2 screens!
                if !hinge.isFolded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if !isSpinning {
                            beginUnbox()
                        }
                    }
                }
            }
            .onChange(of: geo.size) { newSize in
                hinge.evaluateGeometry(width: newSize.width, height: newSize.height)
            }
            .onReceive(appsModel.$scanDone) { done in
                if done && pendingUnbox && !hinge.isFolded {
                    DispatchQueue.main.async { beginUnbox() }
                }
            }
            .onReceive(appsModel.$apps) { _ in
                // The installed-app scan finished: rebuild the reel with real apps.
                if !isSpinning && !showCrate {
                    DispatchQueue.main.async { generateReel() }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Top Hardware Bar
    private var topHardwareBar: some View {
        HStack(spacing: 10) {
            // Live Status Indicator & Resolution
            HStack(spacing: 6) {
                Circle()
                    .fill(hinge.isFolded ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: hinge.isFolded ? .orange : .green, radius: 4)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(hinge.sensorStatus)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(hinge.displayMetrics)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)

            Spacer()

            // Interactive Mode Toggle (1 Screen vs 2 Screens)
            HStack(spacing: 4) {
                Button(action: {
                    hinge.setFoldedState(true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "iphone")
                        Text("1 Screen")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(hinge.isFolded ? .black : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(hinge.isFolded ? Color.yellow : Color.clear)
                    .cornerRadius(7)
                }

                Button(action: {
                    hinge.setFoldedState(false)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                        Text("2 Screens")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(!hinge.isFolded ? .black : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(!hinge.isFolded ? Color.yellow : Color.clear)
                    .cornerRadius(7)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.1))
            .cornerRadius(9)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
    }

    // MARK: - 1. Cover Screen
    private func foldedCoverView(width: CGFloat, height: CGFloat) -> some View {
        let gold = LinearGradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.62), Color(red: 1.0, green: 0.72, blue: 0.10)],
                                  startPoint: .top, endPoint: .bottom)
        return ZStack {
            LinearGradient(colors: [Color(red: 0.055, green: 0.042, blue: 0.02), .black],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                // Header Title + Subtitle for Active Category
                VStack(spacing: 8) {
                    Text("APP UNBOXED")
                        .font(.system(size: min(width * 0.088, 36), weight: .heavy, design: .rounded))
                        .kerning(min(width * 0.02, 8))
                        .foregroundStyle(gold)
                        .shadow(color: Color(red: 1, green: 0.75, blue: 0.1).opacity(0.55), radius: 16)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .onTapGesture {
                            titleTapCount += 1
                            if titleTapCount >= 3 {
                                titleTapCount = 0
                                forceGoldNext.toggle()
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            }
                        }

                    Text(forceGoldNext ? "★ GOLD VAULT PRIMED FOR NEXT SPIN ★" : appsModel.selectedCategory.subtitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .kerning(2)
                        .foregroundColor(forceGoldNext ? .yellow : .white.opacity(0.55))
                        .animation(.easeInOut(duration: 0.2), value: forceGoldNext)
                }
                .padding(.top, max(28, height * 0.065))
                .padding(.horizontal, 20)

                // The 3D rotating loot box. Tapping it opens a case without unfolding.
                CoverCrate()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { hinge.setFoldedState(false) }

                // 6 Category Toggles (ALL + 5 Big Categories)
                categorySelectorView(width: width)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)

                // Bottom prompt / scan status
                VStack(spacing: 8) {
                    if appsModel.scanDone {
                        Text("OPEN YOUR IPHONE DUO")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .kerning(3)
                            .foregroundColor(.white)
                            .opacity(pulseGlow ? 1 : 0.4)
                            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: pulseGlow)

                        let currentCount = appsModel.count(for: appsModel.selectedCategory)
                        Text("\(currentCount) \(appsModel.selectedCategory.title) APPS · OR TAP THE BOX")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .kerning(1.5)
                            .foregroundColor(.white.opacity(0.45))
                    } else {
                        Text("SCANNING YOUR APPS")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .kerning(3)
                            .foregroundColor(.white.opacity(0.85))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(gold)
                                .frame(width: max(6, 190 * CGFloat(appsModel.scanFraction)))
                                .animation(.easeOut(duration: 0.4), value: appsModel.scanFraction)
                        }
                        .frame(width: 190, height: 3)
                        Text("\(appsModel.apps.count) FOUND SO FAR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .kerning(1.5)
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .frame(height: 52)
                .padding(.bottom, max(20, height * 0.045))
                .onAppear { pulseGlow = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category Selector View (6 Toggles)
    private func categorySelectorView(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                pillFor(.all)
                pillFor(.games)
                pillFor(.social)
            }
            HStack(spacing: 8) {
                pillFor(.media)
                pillFor(.food)
                pillFor(.tools)
            }
        }
    }

    private func pillFor(_ cat: AppCategory) -> some View {
        CategoryPillButton(
            category: cat,
            isSelected: appsModel.selectedCategory == cat,
            count: appsModel.count(for: cat),
            scanDone: appsModel.scanDone,
            onSelect: {
                guard appsModel.selectedCategory != cat else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    appsModel.selectedCategory = cat
                    generateReel()
                }
            }
        )
    }

    // MARK: - 2. Fullscreen Case Roll
    private let reelStartIndex: CGFloat = 3
    private let rollDuration: Double = 6.4
    // Fast launch, long glide to a stop (same curve drives the tick timing).
    private let rollCurve: (Double, Double, Double, Double) = (0.10, 0.70, 0.12, 1.0)

    private func unfoldedDualScreenView(width: CGFloat, height: CGFloat) -> some View {
        let cardH = min(max(height * 0.40, 170), 300)
        let cardW = cardH * 0.78
        let spacing = cardW * 0.07
        let accent: Color = landed ? Color(winningApp?.color ?? .yellow) : .yellow

        return ZStack {
            // Backdrop: near-black with a soft glow that takes the winner's rarity colour.
            LinearGradient(colors: [Color(red: 0.035, green: 0.04, blue: 0.065), .black],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [accent.opacity(landed ? 0.30 : 0.09), .clear],
                           center: .center, startRadius: 10, endRadius: max(width, height) * 0.55)
                .animation(.easeOut(duration: 0.5), value: landed)

            // The strip and its marker: Core Animation layers, animated off the main thread.
            ReelStrip(controller: reel, cardSize: CGSize(width: cardW, height: cardH), spacing: spacing)
                .frame(width: width, height: cardH * 1.3 + 40)

            // Header / footer
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("APP UNBOXED")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .kerning(5)
                        .foregroundColor(.white.opacity(0.55))

                    Text("·")
                        .foregroundColor(.white.opacity(0.3))

                    Button(action: {
                        let all = AppCategory.allCases
                        if let idx = all.firstIndex(of: appsModel.selectedCategory) {
                            let next = all[(idx + 1) % all.count]
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                appsModel.selectedCategory = next
                                generateReel()
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: appsModel.selectedCategory.iconSymbol)
                                .font(.system(size: 10, weight: .bold))
                            Text(appsModel.selectedCategory.title + " CASE")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .opacity(0.6)
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.14))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.top, max(26, height * 0.06))

                Spacer()

                Group {
                    if pendingUnbox {
                        VStack(spacing: 10) {
                            ProgressView().tint(.yellow)
                            Text("SCANNING YOUR APPS…")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .kerning(2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .transition(.opacity)
                    } else if landed, let app = winningApp {
                        VStack(spacing: 6) {
                            if isGoldSequence && !isGoldSecondSpin {
                                Text("★ SPECIAL RARE ITEM HIT! ★")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .kerning(3)
                                    .foregroundColor(Color.yellow)
                                Text("GOLD VAULT")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("UNLOCKING SECOND SPIN…")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .kerning(2)
                                    .foregroundColor(Color.yellow.opacity(0.85))
                            } else {
                                Text(app.rarity == "gold" ? "★ SPECIAL RARE ITEM ★" : app.rarity.uppercased())
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .kerning(3)
                                    .foregroundColor(Color(app.color))
                                Text(app.name)
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                Text("OPENING…")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .kerning(2)
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if !isSpinning {
                        Button(action: { beginUnbox() }) {
                            Text("OPEN ANOTHER CASE")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .kerning(2)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.yellow))
                                .shadow(color: Color.yellow.opacity(0.45), radius: 14)
                        }
                        .transition(.opacity)
                    } else {
                        oddsLegend
                            .transition(.opacity)
                    }
                }
                .frame(height: 92)
                .padding(.horizontal, 24)

                HStack(spacing: 14) {
                    Text(appsModel.sourceStatus)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !isSpinning && !landed && !pendingUnbox {
                        Button(action: { showAddApps = true }) {
                            Text("＋ ADD APPS")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, max(18, height * 0.035))
            }
            .animation(.easeOut(duration: 0.35), value: landed)
            .animation(.easeOut(duration: 0.35), value: isSpinning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .sheet(isPresented: $showAddApps, onDismiss: { appsModel.scan() }) {
            AddAppsView(model: appsModel)
        }
    }

    /// Drop odds as one quiet row of coloured dots.
    private var oddsLegend: some View {
        let tiers: [(String, Color)] = [
            ("46%", Color(red: 0.29, green: 0.41, blue: 1.0)),
            ("28%", Color(red: 0.53, green: 0.28, blue: 1.0)),
            ("16%", Color(red: 0.83, green: 0.17, blue: 0.9)),
            ("8%", Color(red: 0.92, green: 0.29, blue: 0.29)),
            ("2%", Color(red: 1.0, green: 0.84, blue: 0.0)),
        ]
        return HStack(spacing: 18) {
            ForEach(Array(tiers.enumerated()), id: \.offset) { _, tier in
                HStack(spacing: 6) {
                    Circle().fill(tier.1).frame(width: 7, height: 7).shadow(color: tier.1, radius: 4)
                    Text(tier.0)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    // Card: icon on a dark plate lit from below in the rarity colour.
    private func cardView(app: AppEntry, width: CGFloat, height: CGFloat) -> some View {
        let tint = Color(app.color)
        let iconSide = width * 0.56
        return VStack(spacing: height * 0.07) {
            appIcon(app, size: iconSide, symbolSize: iconSide * 0.5, radius: iconSide * 0.225, stroke: 2)
            Text(app.name)
                .font(.system(size: max(12, width * 0.085), weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
        }
        .frame(width: width, height: height)
        .background(
            ZStack {
                Color(red: 0.075, green: 0.082, blue: 0.115)
                LinearGradient(colors: [.clear, tint.opacity(0.34)], startPoint: .center, endPoint: .bottom)
            }
        )
        .overlay(
            VStack {
                Spacer()
                Rectangle().fill(tint).frame(height: 4).shadow(color: tint, radius: 6)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: width * 0.085, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.085, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    /// The app's real icon when iOS provides it, otherwise the symbol tile.
    @ViewBuilder
    private func appIcon(_ app: AppEntry, size: CGFloat, symbolSize: CGFloat, radius: CGFloat, stroke: CGFloat) -> some View {
        if app.rarity == "gold" && !app.isRevealedGold {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.58), Color(red: 1.0, green: 0.78, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                Text("?")
                    .font(.system(size: symbolSize * 1.35, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.55, green: 0.3, blue: 0.0).opacity(0.8), radius: 4, x: 0, y: 2)
            }
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: stroke)
                    .shadow(color: Color.yellow.opacity(0.7), radius: 8)
            )
        } else if let icon = app.icon {
            Image(uiImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: Color(app.color).opacity(0.75), radius: 9)
        } else {
            Image(systemName: app.systemIcon)
                .font(.system(size: symbolSize))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Color(app.color).opacity(0.2))
                .cornerRadius(radius)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color(app.color), lineWidth: stroke)
                        .shadow(color: Color(app.color).opacity(0.6), radius: 8)
                )
        }
    }

    private func rarityRow(title: String, color: Color, desc: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
    }

    // Winner Banner Overlay
    private func winnerBannerOverlay(app: AppEntry) -> some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                Text(app.rarity == "gold" ? "★ SPECIAL RARE ITEM ★" : "★ UNBOXED ★")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)

                appIcon(app, size: 120, symbolSize: 68, radius: 27, stroke: 3)

                VStack(spacing: 4) {
                    Text(app.name)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text("\(app.rarity.uppercased()) APP")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(app.color))
                }

                Text("🚀 AUTO-LAUNCHING APP NOW...")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(28)
            .background(Color(red: 0.1, green: 0.12, blue: 0.16))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(app.color).opacity(0.8), lineWidth: 2)
            )
        }
        .transition(.opacity)
    }

    // MARK: - Sequence & Auto-Launch
    private func generateReel() {
        var items: [AppEntry] = []
        for _ in 0..<totalReelCards {
            if let randomApp = appsModel.randomWeighted() {
                items.append(randomApp)
            }
        }
        self.reelItems = items
        reel.load(items: items, position: reelStartIndex)
    }

    /// Plays the crate cinematic, then the reel. Entry point for every spin.
    private func beginUnbox() {
        guard !isSpinning, !showCrate else { return }
        // Wait for the first full app scan, so the reel holds every app found.
        guard appsModel.scanDone else { pendingUnbox = true; return }
        pendingUnbox = false
        showWinnerBanner = false
        isGoldSequence = false
        isGoldSecondSpin = false
        finalGoldWinner = nil
        statusText = "CASE INBOUND // STAND BY..."
        landed = false
        InstalledAppsModel.heavyScanPaused = true

        var items: [AppEntry] = []
        for _ in 0..<totalReelCards {
            if let app = appsModel.randomWeighted() { items.append(app) }
        }
        guard items.count > winnerTargetIndex else { return }

        // Check if user hit gold naturally (2%) or primed it for testing:
        let isGoldHit = forceGoldNext || (items[winnerTargetIndex].rarity == "gold")
        forceGoldNext = false

        if isGoldHit {
            isGoldSequence = true
            // Select the actual winning gold app for the 2nd spin:
            let allGoldCandidates = appsModel.apps.filter { $0.rarity == "gold" }
            let goldPool = allGoldCandidates.isEmpty ? appsModel.apps : allGoldCandidates
            let chosenWinner = (goldPool.randomElement() ?? items[winnerTargetIndex]).asRevealed()
            finalGoldWinner = chosenWinner

            // Replace the winner on the 1st reel with the iconic Mystery Gold '?' card:
            let mysteryCard = AppEntry(id: "com.appunboxed.mystery.gold", name: "★ SPECIAL ITEM ★", scheme: "",
                                       rarity: "gold", systemIcon: "questionmark", icon: nil,
                                       category: appsModel.selectedCategory, isRevealedGold: false)
            items[winnerTargetIndex] = mysteryCard
            winningApp = mysteryCard
        } else {
            winningApp = items[winnerTargetIndex]
        }

        reelItems = items
        reel.load(items: items, position: reelStartIndex)
        showCrate = true
    }

    private func startRoll() {
        guard !isSpinning, let winner = winningApp else { return }
        isSpinning = true
        landed = false
        statusText = "CASE DEPLOYED // ROLLING..."

        // Stop a little off-centre inside the winning card, like the real thing.
        let start = Double(reelStartIndex)
        let target = Double(winnerTargetIndex) + Double.random(in: -0.3...0.3)
        reel.roll(to: CGFloat(target), duration: rollDuration, curve: rollCurve)

        // One tick each time a card edge passes the marker. Haptics are thinned
        // out during the fast opening stretch; the sound is not.
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        var lastHaptic = -1.0
        for time in tickTimes(from: start, to: target, duration: rollDuration) {
            let withHaptic = time - lastHaptic >= 0.07
            if withHaptic { lastHaptic = time }
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                CSGOAudioPlayer.shared.playTick()
                reel.tick()
                if withHaptic { feedback.impactOccurred() }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration + 0.2) {
            reel.land(on: winnerTargetIndex, accent: winner.color)
            landed = true
            CSGOAudioPlayer.shared.playWin()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if isGoldSequence, finalGoldWinner != nil {
                // Gold Mystery Item hit! Announce and prepare for the 2nd spin!
                statusText = "★ SPECIAL RARE ITEM HIT! ★"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    startGoldSecondSpin()
                }
            } else {
                InstalledAppsModel.heavyScanPaused = false
                isSpinning = false
                statusText = "LANDED: \(winner.name.uppercased())!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                    appsModel.launch(app: winner)
                }
            }
        }
    }

    /// Second spin animation: triggered when the first reel hits the 2% Gold mystery item!
    /// The entire reel transforms into all-gold items, spins, and reveals the final gold app!
    private func startGoldSecondSpin() {
        guard let finalWinner = finalGoldWinner else { return }
        isGoldSecondSpin = true
        isSpinning = true
        landed = false
        statusText = "★ GOLD VAULT UNLOCKED // SPINNING FOR GOLD... ★"

        // Build All-Gold Reel
        let allGold = appsModel.apps.filter { $0.rarity == "gold" }.map { $0.asRevealed() }
        let basePool = allGold.isEmpty ? appsModel.apps.map { $0.asRevealed() } : allGold

        var goldReelItems: [AppEntry] = []
        for _ in 0..<totalReelCards {
            goldReelItems.append(basePool.randomElement() ?? finalWinner)
        }
        goldReelItems[winnerTargetIndex] = finalWinner
        reelItems = goldReelItems

        // Load into reel strip and start second roll
        reel.load(items: goldReelItems, position: reelStartIndex)

        let goldRollDuration: Double = 5.0
        let start = Double(reelStartIndex)
        let target = Double(winnerTargetIndex) + Double.random(in: -0.25...0.25)
        reel.roll(to: CGFloat(target), duration: goldRollDuration, curve: rollCurve)

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        var lastHaptic = -1.0
        for time in tickTimes(from: start, to: target, duration: goldRollDuration) {
            let withHaptic = time - lastHaptic >= 0.065
            if withHaptic { lastHaptic = time }
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                CSGOAudioPlayer.shared.playTick()
                reel.tick()
                if withHaptic { feedback.impactOccurred() }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + goldRollDuration + 0.2) {
            reel.land(on: winnerTargetIndex, accent: finalWinner.color)
            InstalledAppsModel.heavyScanPaused = false
            isSpinning = false
            landed = true
            winningApp = finalWinner
            statusText = "★ UNBOXED: \(finalWinner.name.uppercased())! ★"
            CSGOAudioPlayer.shared.playWin()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                appsModel.launch(app: finalWinner)
            }
        }
    }

    /// When each card edge crosses the marker, found by walking the same
    /// bezier curve the animation uses, so there is one tick per card. Only
    /// crossings under 22 ms apart (the first few cards at launch) are merged.
    private func tickTimes(from: Double, to: Double, duration: Double = 6.4) -> [Double] {
        func bezier(_ u: Double, _ a: Double, _ b: Double) -> Double {
            let m = 1 - u
            return 3 * m * m * u * a + 3 * m * u * u * b + u * u * u
        }
        var times: [Double] = []
        var last = -1.0
        var u = 0.0
        var edge = from.rounded(.down) + 0.5
        if edge <= from { edge += 1 }
        while edge < to {
            let fraction = (edge - from) / (to - from)
            while u < 1, bezier(u, rollCurve.1, rollCurve.3) < fraction { u += 0.0005 }
            let time = bezier(u, rollCurve.0, rollCurve.2) * duration
            if time - last >= 0.022 {
                times.append(time)
                last = time
            }
            edge += 1
        }
        return times
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CategoryPillButton: View {
    let category: AppCategory
    let isSelected: Bool
    let count: Int
    let scanDone: Bool
    let onSelect: () -> Void

    private static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.88, blue: 0.35), Color(red: 0.95, green: 0.68, blue: 0.05)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                Image(systemName: category.iconSymbol)
                    .font(.system(size: 11, weight: .bold))

                Text(category.title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if scanDone && count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.black.opacity(0.2) : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? Color.yellow : Color.white.opacity(0.14), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Color.yellow.opacity(0.45) : .clear, radius: 8, x: 0, y: 0)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            Self.goldGradient
        } else {
            Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.92)
        }
    }
}
