import SwiftUI

struct GameView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var gameState = GameState()
    @StateObject private var interactionState = BoardInteractionState()
    @State private var showHelp = false
    @State private var showPaintMatch = false
    @State private var isBottomBarCollapsed = false
    @State private var prefersDarkTheme = false
    @State private var modeSelection = 1
    @State private var welcomeBackgroundOpacity: CGFloat = 0
    @State private var welcomeLeftNodeScale: CGFloat = 0.78
    @State private var welcomeMiddleNodeScale: CGFloat = 0.78
    @State private var welcomeRightNodeScale: CGFloat = 0.78
    @State private var welcomeFirstSegmentProgress: CGFloat = 0
    @State private var welcomeSecondSegmentProgress: CGFloat = 0
    @State private var welcomeAccentOpacity: CGFloat = 0.1
    @State private var welcomeLogoOpacity: CGFloat = 0
    @State private var welcomeTitleOpacity: CGFloat = 0
    @State private var welcomeSubtitleOpacity: CGFloat = 0
    @State private var welcomeTaglineOpacity: CGFloat = 0
    @State private var welcomeCTAOpacity: CGFloat = 0
    @State private var welcomeCTAOffset: CGFloat = 8
    @State private var welcomeDidAnimate = false
    @State private var expandedHelpCardID: String?
    @State private var helpReplaySeed: [String: Int] = [:]

    var body: some View {
        ZStack {
            AppTheme.paperBackground.ignoresSafeArea()

            switch gameState.flowState {
            case .welcome:
                welcomeView
            case .setup, .play:
                gameSurface
            }
        }
        .sheet(isPresented: $showHelp) {
            helpSheet
        }
        .fullScreenCover(isPresented: $showPaintMatch) {
            PaintMatchView(
                edges: gameState.edges,
                dots: gameState.dots,
                isJuniorPalette: false
            )
        }
        .preferredColorScheme(prefersDarkTheme ? .dark : .light)
    }

    private var welcomeView: some View {
        GeometryReader { proxy in
            let isPadScale = (horizontalSizeClass == .regular) && proxy.size.width >= 700
            let titleSize = isPadScale ? min(96, max(72, proxy.size.width * 0.085)) : 62
            let subtitleSize = isPadScale ? min(38, max(32, proxy.size.width * 0.035)) : 24
            let taglineSize = isPadScale ? 21.0 : 15.0
            let logoScale = isPadScale ? 1.4 : 1.0
            let ctaWidth = isPadScale ? min(380, max(320, proxy.size.width * 0.34)) : 220
            let ctaHeight = isPadScale ? min(82, max(72, proxy.size.height * 0.085)) : 54
            let titleBlockSpacing = isPadScale ? 16.0 : 10.0
            let sectionSpacing = isPadScale ? 46.0 : 28.0
            let verticalOffset = isPadScale ? -34.0 : -8.0

            ZStack {
                welcomeBackground
                VStack(spacing: sectionSpacing) {
                    Spacer()
                    VStack(spacing: titleBlockSpacing) {
                        InkSeedLogoSymbol(
                            firstSegmentProgress: welcomeFirstSegmentProgress,
                            secondSegmentProgress: welcomeSecondSegmentProgress,
                            leftNodeScale: welcomeLeftNodeScale,
                            middleNodeScale: welcomeMiddleNodeScale,
                            rightNodeScale: welcomeRightNodeScale,
                            accentOpacity: welcomeAccentOpacity,
                            useAccentMiddleNode: true
                        )
                        .frame(height: 66 * logoScale)
                        .padding(.bottom, isPadScale ? 12 : 6)
                        .opacity(welcomeLogoOpacity)

                        Text("InkSeed")
                            .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.graphiteInk.opacity(0.98))
                            .opacity(welcomeTitleOpacity)

                        Text("Calm strategy through drawing.")
                            .font(.system(size: subtitleSize, weight: .regular, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .opacity(welcomeSubtitleOpacity)

                        Text("Every move plants a possibility.")
                            .font(.system(size: taglineSize, weight: .regular, design: .serif))
                            .tracking(isPadScale ? 0.62 : 0.45)
                            .foregroundStyle(secondaryTextColor.opacity(0.88))
                            .opacity(welcomeTaglineOpacity)
                    }

                    VStack(spacing: isPadScale ? 16 : 10) {
                        Button {
                            gameState.startNewGame()
                        } label: {
                            Text("Start Drawing")
                                .font(.system(size: isPadScale ? 29 : 22, weight: .semibold, design: .rounded))
                                .frame(width: ctaWidth, height: ctaHeight)
                        }
                        .buttonStyle(PremiumLaunchButtonStyle(accent: AppTheme.royalPurple))
                        .opacity(welcomeCTAOpacity)
                        .offset(y: welcomeCTAOffset)
                    }
                    Spacer()
                }
                .offset(y: verticalOffset)
            }
        }
        .padding()
        .onAppear {
            startWelcomeLogoAnimationIfNeeded()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            skipWelcomeAnimation()
        }
    }

    private var gameSurface: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 10) {
                topBar

                BoardView(
                    gameState: gameState,
                    interactionState: interactionState,
                    accentColor: currentAccentColor
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

                if !isBottomBarCollapsed {
                    bottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 10)

            if isBottomBarCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        isBottomBarCollapsed = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.graphiteInk.opacity(0.56))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.paperSecondary.opacity(0.86), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, isBottomBarCollapsed ? 6 : 12)
        .animation(.easeInOut(duration: 0.28), value: isBottomBarCollapsed)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("New Game") {
                    gameState.startNewGame()
                }
                .buttonStyle(.borderedProminent)

                Button("Restart") {
                    gameState.restartPlay()
                }
                .buttonStyle(.bordered)

                Button("?") {
                    showHelp = true
                }
                .buttonStyle(.bordered)
                .tint(currentAccentColor.opacity(0.26))
                .foregroundStyle(AppTheme.graphiteInk.opacity(0.8))
            }

            Spacer()

            InkSeedLogoSymbol()
                .frame(width: 34, height: 16)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.38), lineWidth: 0.7)
                )

            Spacer()

            Button {
                prefersDarkTheme.toggle()
            } label: {
                InkSeedThemeGlyph(isDark: prefersDarkTheme)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.bordered)
            .tint(currentAccentColor.opacity(0.26))
            .foregroundStyle(AppTheme.graphiteInk.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .tint(currentAccentColor)
    }

    private var bottomBar: some View {
        Group {
            if gameState.flowState == .setup {
                setupFooter
            } else {
                playerFooter
            }
        }
        .overlay(alignment: .top) {
            Button {
                withAnimation(.easeInOut(duration: 0.28)) {
                    isBottomBarCollapsed = true
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.graphiteInk.opacity(0.52))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.paperBackground.opacity(0.9), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.graphiteInk.opacity(0.12), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .offset(y: -14)
        }
    }

    private var setupFooter: some View {
        HStack(spacing: 14) {
            Text("Place 3–6 dots to begin")
                .font(.headline)
                .foregroundStyle(AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.9 : 0.75))

            Text("\(gameState.dots.count)/\(gameState.maxSetupDots)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(secondaryTextColor)

            Button("Undo") {
                gameState.removeLastSetupDot()
            }
            .buttonStyle(.bordered)
            .disabled(gameState.dots.isEmpty)

            Button("Start Drawing") {
                gameState.finalizeSetupIfPossible()
            }
            .buttonStyle(.borderedProminent)
            .disabled(gameState.dots.count < gameState.minSetupDots)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bottomBarBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? .white.opacity(0.08) : .clear, lineWidth: 0.8)
        }
        .tint(currentAccentColor)
    }

    private var playerFooter: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(playerColor(for: gameState.currentPlayer))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn: \(gameState.currentPlayer.title)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.95 : 0.8))

                    Text(phaseHint)
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                }
            }

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Button(modeSelection == 1 ? "Need help?" : "Check moves") {
                    checkMovesTapped()
                }
                .buttonStyle(.bordered)
                .tint(currentAccentColor.opacity(0.9))
                .disabled(gameState.winner != nil || gameState.flowState != .play)

                if let winner = gameState.winner {
                    Text("\(winner.title) wins")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(playerColor(for: winner).opacity(0.22), in: Capsule())
                        .overlay(
                            Capsule().stroke(playerColor(for: winner).opacity(0.42), lineWidth: 0.8)
                        )

                    Button {
                        showPaintMatch = true
                    } label: {
                        Label("Paint the Match", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentAccentColor)
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bottomBarBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? .white.opacity(0.08) : .clear, lineWidth: 0.8)
        }
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(helpCards) { card in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.title)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(AppTheme.graphiteInk.opacity(0.95))
                                    Text(card.description)
                                        .font(.title3)
                                        .foregroundStyle(secondaryTextColor.opacity(0.98))
                                }
                                Spacer(minLength: 8)
                                if expandedHelpCardID == card.id {
                                    Button("↻") {
                                        helpReplaySeed[card.id, default: 0] += 1
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(currentAccentColor.opacity(0.8))
                                }
                            }

                            if expandedHelpCardID == card.id {
                                HelpMiniDemoView(
                                    demo: card.demo,
                                    replaySeed: helpReplaySeed[card.id, default: 0],
                                    accent: currentAccentColor,
                                    isDark: colorScheme == .dark
                                )
                                .frame(height: 92)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(helpCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(colorScheme == .dark ? .white.opacity(0.08) : .clear, lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 8, x: 0, y: 4)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                if expandedHelpCardID == card.id {
                                    expandedHelpCardID = nil
                                } else {
                                    expandedHelpCardID = card.id
                                    // Tap-to-open immediately restarts demo (no replay required).
                                    helpReplaySeed[card.id, default: 0] += 1
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("How to Play ✨")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Let's Draw!") {
                        showHelp = false
                    }
                }
            }
        }
    }
    
    private var phaseHint: String {
        switch gameState.turnPhase {
        case .drawLine:
            return "Phase A: draw line"
        case .placeNewDot:
            return "Phase B: tap line to place new dot"
        }
    }

    private func checkMovesTapped() {
        guard gameState.flowState == .play, gameState.winner == nil else { return }

        let hasLegalMove = RulesEngine.hasAnyLegalMove(
            gameState: gameState,
            profile: gameState.geometryProfile
        )

        if hasLegalMove {
            interactionState.showInvalid("A move may still exist.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                interactionState.hideFeedback()
            }
        } else {
            // Manual check: winner is last valid mover, i.e. opposite of current player.
            gameState.winner = previousPlayer
        }
    }

    private var previousPlayer: Player {
        gameState.currentPlayer == .one ? .two : .one
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(hex: 0xB9B2A8).opacity(0.96) : AppTheme.graphiteInk.opacity(0.62)
    }

    private var bottomBarBackground: Color {
        colorScheme == .dark ? Color(hex: 0x17191E, alpha: 0.96) : AppTheme.paperSecondary.opacity(0.68)
    }

    private var currentAccentColor: Color {
        AppTheme.warmOrange
    }

    private func playerColor(for player: Player) -> Color {
        player == .one ? AppTheme.playerOneUndertone : AppTheme.playerTwoUndertone
    }

    private var helpCardBackground: Color {
        colorScheme == .dark ? Color(hex: 0x1F2228, alpha: 0.96) : Color(hex: 0xF8EFE1, alpha: 0.92)
    }

    private var helpCards: [HelpCard] {
        [
            HelpCard(id: "place", title: "1️⃣ Place Dots", description: "Put 3–6 dots anywhere.", demo: .placeDots),
            HelpCard(id: "draw", title: "2️⃣ Draw a Line", description: "Connect two dots.", demo: .drawLine),
            HelpCard(id: "newdot", title: "3️⃣ Add New Dot", description: "Tap the line to grow the board.", demo: .addDot),
            HelpCard(id: "max3", title: "4️⃣ Max 3 Links", description: "Each dot can have up to 3 connections.", demo: .maxLinks),
            HelpCard(id: "cross", title: "5️⃣ No Crossing", description: "Lines cannot cross.", demo: .noCrossing),
            HelpCard(id: "finish", title: "6️⃣ Finish the Match", description: "When no moves remain, winner appears.", demo: .finishMatch),
            HelpCard(id: "bonus", title: "🎨 Bonus", description: "After the match, paint the spaces and make art.", demo: .paintBonus)
        ]
    }

    private var welcomeBackground: some View {
        ZStack {
            AppTheme.paperBackground
            RadialGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.09 : 0.22),
                    .clear
                ],
                center: .center,
                startRadius: 16,
                endRadius: 520
            )
            Canvas { context, size in
                let count = Int((size.width * size.height) / 6200)
                for index in 0..<max(45, count) {
                    let seed = CGFloat(index + 1)
                    let x = pseudoRandom(seed * 13.21) * size.width
                    let y = pseudoRandom(seed * 27.77) * size.height
                    let dot = CGRect(x: x, y: y, width: 0.85, height: 0.85)
                    context.fill(
                        Path(ellipseIn: dot),
                        with: .color(AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.03 : 0.022))
                    )
                }
            }
            .blendMode(.overlay)
        }
        .opacity(welcomeBackgroundOpacity)
        .ignoresSafeArea()
    }

    private func startWelcomeLogoAnimationIfNeeded() {
        guard !welcomeDidAnimate else { return }
        welcomeDidAnimate = true

        welcomeBackgroundOpacity = 0
        welcomeLeftNodeScale = 0.82
        welcomeMiddleNodeScale = 0.78
        welcomeRightNodeScale = 0.76
        welcomeFirstSegmentProgress = 0
        welcomeSecondSegmentProgress = 0
        welcomeAccentOpacity = 0.1
        welcomeLogoOpacity = 0
        welcomeTitleOpacity = 0
        welcomeSubtitleOpacity = 0
        welcomeTaglineOpacity = 0
        welcomeCTAOpacity = 0
        welcomeCTAOffset = 8

        withAnimation(.easeOut(duration: 0.22)) {
            welcomeBackgroundOpacity = 1
        }
        withAnimation(.spring(response: 0.16, dampingFraction: 0.86).delay(0.2)) {
            welcomeLogoOpacity = 1
            welcomeLeftNodeScale = 1
        }
        withAnimation(.easeOut(duration: 0.2).delay(0.5)) {
            welcomeFirstSegmentProgress = 1
            welcomeSecondSegmentProgress = 1
        }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.9).delay(0.56)) {
            welcomeMiddleNodeScale = 1
        }
        withAnimation(.spring(response: 0.14, dampingFraction: 0.92).delay(0.62)) {
            welcomeRightNodeScale = 1
        }
        withAnimation(.easeOut(duration: 0.16).delay(0.8)) {
            welcomeTitleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.16).delay(1.1)) {
            welcomeSubtitleOpacity = 1
            welcomeTaglineOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.18).delay(1.4)) {
            welcomeCTAOpacity = 1
            welcomeCTAOffset = 0
            welcomeAccentOpacity = 0.18
        }
    }

    private func skipWelcomeAnimation() {
        guard welcomeDidAnimate else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            welcomeBackgroundOpacity = 1
            welcomeLogoOpacity = 1
            welcomeLeftNodeScale = 1
            welcomeMiddleNodeScale = 1
            welcomeRightNodeScale = 1
            welcomeFirstSegmentProgress = 1
            welcomeSecondSegmentProgress = 1
            welcomeTitleOpacity = 1
            welcomeSubtitleOpacity = 1
            welcomeTaglineOpacity = 1
            welcomeCTAOpacity = 1
            welcomeCTAOffset = 0
            welcomeAccentOpacity = 0.18
        }
    }

    private func pseudoRandom(_ value: CGFloat) -> CGFloat {
        let raw = sin(value * 12.9898) * 43758.5453
        return raw - floor(raw)
    }
}

#Preview {
    GameView()
}

private struct PremiumLaunchButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(accent)
                    .shadow(color: accent.opacity(0.34), radius: 14, x: 0, y: 7)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct InkSeedThemeGlyph: View {
    let isDark: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if isDark {
                // Elegant sun glyph with thin rays.
                Circle()
                    .stroke(glyphColor.opacity(0.92), lineWidth: 1.25)
                    .frame(width: 8.2, height: 8.2)

                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 0.7, style: .continuous)
                        .fill(glyphColor.opacity(0.86))
                        .frame(width: 1.0, height: 3.2)
                        .offset(y: -6.3)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
            } else {
                // Crescent moon (custom), intentionally not SF Symbol look.
                Circle()
                    .fill(glyphColor.opacity(0.9))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(backgroundMaskColor)
                    .frame(width: 9, height: 9)
                    .offset(x: 3.1, y: -0.4)
            }
        }
        .drawingGroup()
    }

    private var glyphColor: Color {
        AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.94 : 0.82)
    }

    private var backgroundMaskColor: Color {
        AppTheme.paperSecondary
    }
}

private struct HelpCard: Identifiable {
    let id: String
    let title: String
    let description: String
    let demo: HelpDemoType
}

private enum HelpDemoType {
    case placeDots
    case drawLine
    case addDot
    case maxLinks
    case noCrossing
    case finishMatch
    case paintBonus
}

private struct HelpMiniDemoView: View {
    let demo: HelpDemoType
    let replaySeed: Int
    let accent: Color
    let isDark: Bool

    @State private var p1: CGFloat = 0
    @State private var p2: CGFloat = 0
    @State private var p3: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((isDark ? Color(hex: 0x17191E) : .white).opacity(isDark ? 0.92 : 0.9))
            Canvas { context, size in
                let ink = isDark ? Color(hex: 0xF2EEE6) : Color(hex: 0x2A2A2A)
                switch demo {
                case .placeDots:
                    drawDot(context: &context, at: CGPoint(x: size.width * 0.25, y: size.height * 0.5), scale: p1, color: ink)
                    drawDot(context: &context, at: CGPoint(x: size.width * 0.5, y: size.height * 0.35), scale: p2, color: ink)
                    drawDot(context: &context, at: CGPoint(x: size.width * 0.75, y: size.height * 0.58), scale: p3, color: ink)
                case .drawLine:
                    let a = CGPoint(x: size.width * 0.24, y: size.height * 0.62)
                    let b = CGPoint(x: size.width * 0.76, y: size.height * 0.38)
                    drawDot(context: &context, at: a, scale: 1, color: ink)
                    drawDot(context: &context, at: b, scale: 1, color: ink)
                    var path = Path()
                    path.move(to: a)
                    path.addQuadCurve(to: b, control: CGPoint(x: size.width * 0.5, y: size.height * 0.22))
                    context.stroke(path.trimmedPath(from: 0, to: p1), with: .color(accent), style: .init(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                case .addDot:
                    let a = CGPoint(x: size.width * 0.18, y: size.height * 0.56)
                    let b = CGPoint(x: size.width * 0.82, y: size.height * 0.42)
                    let m = CGPoint(x: size.width * 0.5, y: size.height * 0.49)
                    var path = Path(); path.move(to: a); path.addLine(to: b)
                    context.stroke(path, with: .color(accent.opacity(0.9)), lineWidth: 2.2)
                    drawDot(context: &context, at: a, scale: 1, color: ink)
                    drawDot(context: &context, at: b, scale: 1, color: ink)
                    drawDot(context: &context, at: m, scale: p1, color: accent)
                case .maxLinks:
                    let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    drawDot(context: &context, at: c, scale: 1, color: ink)
                    let targets = [
                        CGPoint(x: size.width * 0.22, y: size.height * 0.35),
                        CGPoint(x: size.width * 0.8, y: size.height * 0.35),
                        CGPoint(x: size.width * 0.5, y: size.height * 0.78)
                    ]
                    for t in targets {
                        var path = Path(); path.move(to: c); path.addLine(to: t)
                        context.stroke(path, with: .color(accent.opacity(0.9)), lineWidth: 2)
                        drawDot(context: &context, at: t, scale: 1, color: ink)
                    }
                    var reject = Path(); reject.move(to: c); reject.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.74))
                    context.stroke(reject, with: .color(Color(hex: 0xFF6B6B).opacity(p1)), style: .init(lineWidth: 2, lineCap: .round, dash: [4, 3]))
                case .noCrossing:
                    var base = Path()
                    base.move(to: CGPoint(x: size.width * 0.24, y: size.height * 0.72))
                    base.addLine(to: CGPoint(x: size.width * 0.76, y: size.height * 0.3))
                    context.stroke(base, with: .color(ink), lineWidth: 2)
                    var crossing = Path()
                    crossing.move(to: CGPoint(x: size.width * 0.24, y: size.height * 0.3))
                    crossing.addLine(to: CGPoint(x: size.width * 0.76, y: size.height * 0.72))
                    context.stroke(crossing, with: .color(Color(hex: 0xFF6B6B).opacity(p1)), style: .init(lineWidth: 2, lineCap: .round, dash: [4, 3]))
                case .finishMatch:
                    let badgeRect = CGRect(x: size.width * 0.35, y: size.height * 0.28, width: size.width * 0.3, height: size.height * 0.44)
                    context.fill(Path(roundedRect: badgeRect, cornerRadius: 10), with: .color(accent.opacity(0.2 * p1 + 0.05)))
                    context.stroke(Path(roundedRect: badgeRect, cornerRadius: 10), with: .color(accent.opacity(0.5 * p1 + 0.15)), lineWidth: 1)
                case .paintBonus:
                    let rect = CGRect(x: size.width * 0.28, y: size.height * 0.24, width: size.width * 0.44, height: size.height * 0.52)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(ink.opacity(0.8)), lineWidth: 1.8)
                    let fillRect = rect.insetBy(dx: 6, dy: 6)
                    context.fill(Path(roundedRect: fillRect, cornerRadius: 6), with: .color(accent.opacity(0.18 + 0.5 * p1)))
                }
            }
        }
        .onAppear { runOnce() }
        .onChange(of: replaySeed) { _, _ in runOnce() }
    }

    private func drawDot(context: inout GraphicsContext, at point: CGPoint, scale: CGFloat, color: Color) {
        let size: CGFloat = 10 * max(scale, 0.001)
        let rect = CGRect(x: point.x - size * 0.5, y: point.y - size * 0.5, width: size, height: size)
        context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.94)), lineWidth: 1.7)
    }

    private func runOnce() {
        p1 = 0; p2 = 0; p3 = 0
        switch demo {
        case .placeDots, .drawLine, .addDot:
            // ~2.4s readable sequence for kids.
            withAnimation(.easeInOut(duration: 0.75)) { p1 = 1 }
            withAnimation(.easeInOut(duration: 0.75).delay(0.8)) { p2 = 1 }
            withAnimation(.easeInOut(duration: 0.75).delay(1.65)) { p3 = 1 }
        case .maxLinks, .noCrossing, .finishMatch, .paintBonus:
            // ~2.5s gentle single-phase reveal.
            withAnimation(.easeInOut(duration: 2.5)) { p1 = 1 }
            withAnimation(.easeInOut(duration: 0.55).delay(1.7)) { p2 = 1 }
            withAnimation(.easeInOut(duration: 0.45).delay(2.2)) { p3 = 1 }
        }
    }
}
