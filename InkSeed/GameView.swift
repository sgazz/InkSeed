import SwiftUI
import UIKit

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
    @State private var selectedPlayOrientation: PlayOrientation?

    var body: some View {
        ZStack {
            AppTheme.paperBackground.ignoresSafeArea()

            if selectedPlayOrientation == nil {
                orientationChoiceView
            } else {
                switch gameState.flowState {
                case .welcome:
                    welcomeView
                case .setup, .play:
                    gameSurface
                }
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
        .onAppear {
            applyOrientationLockForSelection()
        }
        .onChange(of: selectedPlayOrientation) { _, _ in
            applyOrientationLockForSelection()
        }
    }

    private var orientationChoiceView: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("Choose your play space")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.graphiteInk.opacity(0.96))

            Text("InkSeed works best when the board stays still.")
                .font(.title3)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            HStack(spacing: 14) {
                Button {
                    selectOrientation(.portrait)
                } label: {
                    Label("Portrait", systemImage: "ipad")
                        .frame(width: 168)
                }
                .buttonStyle(InkSeedPrimaryButtonStyle(accent: currentAccentColor, minimumHeight: 52, showsBackground: false))

                Button {
                    selectOrientation(.landscape)
                } label: {
                    Label("Landscape", systemImage: "ipad.landscape")
                        .frame(width: 168)
                }
                .buttonStyle(InkSeedPrimaryButtonStyle(accent: currentAccentColor, minimumHeight: 52, showsBackground: false))
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
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
                            startNewMatch()
                        } label: {
                            Text("Start Drawing")
                                .font(.system(size: isPadScale ? 29 : 22, weight: .semibold, design: .rounded))
                                .frame(width: ctaWidth, height: ctaHeight)
                        }
                        .buttonStyle(InkSeedSecondaryButtonStyle(minimumHeight: ctaHeight))
                        .opacity(welcomeCTAOpacity)
                        .offset(y: welcomeCTAOffset)

                        Button("Change Orientation") {
                            selectedPlayOrientation = nil
                        }
                        .buttonStyle(InkSeedSecondaryButtonStyle())
                        .opacity(welcomeCTAOpacity)
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
                    startNewMatch()
                }
                .buttonStyle(InkSeedPrimaryButtonStyle(accent: currentAccentColor))

                Button("Undo") {
                    undoTapped()
                }
                .buttonStyle(InkSeedSecondaryButtonStyle())
                .disabled(!canUndo)
            }

            Spacer()

            Button("?") {
                showHelp = true
            }
            .buttonStyle(InkSeedCompactButtonStyle())

            Button {
                prefersDarkTheme.toggle()
            } label: {
                InkSeedThemeGlyph(isDark: prefersDarkTheme)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(InkSeedCompactButtonStyle())
        }
        .padding(.horizontal, 12)
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
            HStack(spacing: 10) {
                Text("Place 3–6 dots to begin")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.92 : 0.82))

                Text("\(gameState.dots.count)/\(gameState.maxSetupDots)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 46)
            .background(Color.clear)
            .overlay(
                InkSeedNodeFrame(
                    color: colorScheme == .dark ? .white.opacity(0.8) : AppTheme.graphiteInk.opacity(0.74),
                    glowColor: colorScheme == .dark ? Color(hex: 0xF1E9DB).opacity(0.16) : AppTheme.graphiteInk.opacity(0.06),
                    isDashed: false,
                    emphasized: false,
                    nodeDiameter: 8
                )
            )

            Spacer(minLength: 8)

            Button("Start Drawing") {
                gameState.finalizeSetupIfPossible()
            }
            .buttonStyle(InkSeedSecondaryButtonStyle())
            .disabled(gameState.dots.count < gameState.minSetupDots)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .tint(currentAccentColor)
    }

    private var playerFooter: some View {
        Group {
            if let winner = gameState.winner {
                VStack(spacing: 16) {
                    InkSeedWinnerDisplay(text: "\(winner.title) wins")

                    Button {
                        showPaintMatch = true
                    } label: {
                        Label("Paint the Match", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(InkSeedPrimaryButtonStyle(accent: currentAccentColor))
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(playerColor(for: gameState.currentPlayer))
                                .frame(width: 12, height: 12)

                            Text("Player \(gameState.currentPlayer.title)")
                                .font(.headline)
                                .foregroundStyle(AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.95 : 0.8))
                        }

                        Text(phaseHint)
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer(minLength: 24)

                    Button(modeSelection == 1 ? "Hint" : "Check moves") {
                        checkMovesTapped()
                    }
                    .buttonStyle(InkSeedSecondaryButtonStyle())
                    .disabled(gameState.flowState != .play)
                    .accessibilityLabel(modeSelection == 1 ? "Show hint" : "Check moves")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bottomBarBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? .white.opacity(0.08) : .clear, lineWidth: 0.8)
        }
        .animation(.easeInOut(duration: 0.24), value: gameState.winner != nil)
    }

    private struct InkSeedWinnerDisplay: View {
        let text: String
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Text(text)
                .font(.headline.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.96) : AppTheme.graphiteInk.opacity(0.94))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                .background(Color.clear)
                .overlay(
                    InkSeedNodeFrame(
                        color: frameColor,
                        glowColor: glowColor,
                        isDashed: false,
                        emphasized: false,
                        nodeDiameter: 8
                    )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.05), radius: 6, x: 0, y: 3)
        }

        private var frameColor: Color {
            if colorScheme == .dark {
                return .white.opacity(0.84)
            } else {
                return AppTheme.graphiteInk.opacity(0.8)
            }
        }

        private var glowColor: Color {
            colorScheme == .dark ? Color(hex: 0xF1E9DB).opacity(0.2) : AppTheme.graphiteInk.opacity(0.06)
        }
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(helpCards.enumerated()), id: \.element.id) { index, card in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .stroke(helpCardFrameColor(isExpanded: true), lineWidth: 1.4)
                                        .frame(width: 12, height: 12)
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(secondaryTextColor.opacity(0.94))
                                }
                                .padding(.top, 3)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.title)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(AppTheme.graphiteInk.opacity(colorScheme == .dark ? 0.96 : 0.9))
                                    Text(card.description)
                                        .font(.subheadline)
                                        .foregroundStyle(secondaryTextColor.opacity(0.96))
                                }
                                Spacer(minLength: 8)
                                Button("↻") {
                                    helpReplaySeed[card.id, default: 0] += 1
                                }
                                .buttonStyle(InkSeedCompactButtonStyle())
                            }

                            HelpMiniDemoView(
                                demo: card.demo,
                                replaySeed: helpReplaySeed[card.id, default: 0],
                                accent: currentAccentColor,
                                isDark: colorScheme == .dark
                            )
                            .frame(height: 92)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    (colorScheme == .dark ? Color.white : AppTheme.graphiteInk)
                                        .opacity(0.045)
                                )
                        )
                        .overlay(
                            InkSeedNodeFrame(
                                color: helpCardFrameColor(isExpanded: true),
                                glowColor: helpCardGlowColor(isExpanded: true),
                                isDashed: false,
                                emphasized: true,
                                nodeDiameter: 8
                            )
                        )
                        .shadow(
                            color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                            radius: 9,
                            x: 0,
                            y: 5
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("How to Play")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Let's Draw!") {
                        showHelp = false
                    }
                    .buttonStyle(InkSeedPrimaryButtonStyle(accent: currentAccentColor))
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

    private var canUndo: Bool {
        switch gameState.flowState {
        case .welcome:
            return false
        case .setup:
            return !gameState.dots.isEmpty
        case .play:
            return gameState.turnPhase == .placeNewDot && gameState.pendingMove != nil
        }
    }

    private func undoTapped() {
        switch gameState.flowState {
        case .welcome:
            break
        case .setup:
            gameState.removeLastSetupDot()
        case .play:
            // UI-level undo during play cancels the current in-progress move before commit.
            if gameState.turnPhase == .placeNewDot, gameState.pendingMove != nil {
                gameState.clearPendingMove()
            }
        }
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(hex: 0xB9B2A8).opacity(0.96) : AppTheme.graphiteInk.opacity(0.62)
    }

    private var bottomBarBackground: Color {
        colorScheme == .dark ? Color(hex: 0x17191E, alpha: 0.96) : AppTheme.paperSecondary.opacity(0.68)
    }

    private var currentAccentColor: Color {
        colorScheme == .dark ? Color(hex: 0xF1E9DB) : AppTheme.graphiteInk.opacity(0.86)
    }

    private func playerColor(for player: Player) -> Color {
        player == .one ? AppTheme.playerOneUndertone : AppTheme.playerTwoUndertone
    }

    private var helpCards: [HelpCard] {
        [
            HelpCard(id: "place", title: "Place Dots", description: "Put 3–6 dots anywhere.", demo: .placeDots),
            HelpCard(id: "draw", title: "Draw a Line", description: "Connect two dots.", demo: .drawLine),
            HelpCard(id: "newdot", title: "Add New Dot", description: "Tap the line to grow the board.", demo: .addDot),
            HelpCard(id: "max3", title: "Max 3 Links", description: "Each dot can have up to 3 connections.", demo: .maxLinks),
            HelpCard(id: "cross", title: "No Crossing", description: "Lines cannot cross.", demo: .noCrossing),
            HelpCard(id: "finish", title: "Finish the Match", description: "When no moves remain, winner appears.", demo: .finishMatch),
            HelpCard(id: "bonus", title: "Bonus", description: "After the match, paint the spaces and make art.", demo: .paintBonus)
        ]
    }

    private func helpCardFrameColor(isExpanded: Bool) -> Color {
        if colorScheme == .dark {
            return .white.opacity(isExpanded ? 0.9 : 0.78)
        } else {
            return AppTheme.graphiteInk.opacity(isExpanded ? 0.88 : 0.72)
        }
    }

    private func helpCardGlowColor(isExpanded: Bool) -> Color {
        guard isExpanded else { return .clear }
        if colorScheme == .dark {
            return Color(hex: 0xF1E9DB).opacity(0.2)
        } else {
            return AppTheme.graphiteInk.opacity(0.08)
        }
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

    private func startNewMatch() {
        applyOrientationLockForSelection()
        gameState.startNewGame()
    }

    private func applyOrientationLockForSelection() {
        guard let selectedPlayOrientation else {
            OrientationAppDelegate.updateOrientationLock(.allButUpsideDown)
            return
        }
        OrientationAppDelegate.updateOrientationLock(selectedPlayOrientation.interfaceMask)
    }

    private func selectOrientation(_ orientation: PlayOrientation) {
        selectedPlayOrientation = orientation
        applyOrientationLockForSelection()
        if gameState.flowState != .welcome {
            gameState.enterWelcome()
        }
    }

}

private enum PlayOrientation: Equatable {
    case portrait
    case landscape

    var interfaceMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscape
        }
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

// MARK: - InkSeed Button Styles

struct InkSeedPrimaryButtonStyle: ButtonStyle {
    let accent: Color
    var minimumHeight: CGFloat = 46
    var showsBackground: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        InkSeedNodeFrameButtonBody(
            configuration: configuration,
            variant: .primary(accent: accent, showsBackground: showsBackground),
            minimumHeight: minimumHeight
        )
    }
}

struct InkSeedSecondaryButtonStyle: ButtonStyle {
    var minimumHeight: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        InkSeedNodeFrameButtonBody(
            configuration: configuration,
            variant: .secondary,
            minimumHeight: minimumHeight
        )
    }
}

struct InkSeedCompactButtonStyle: ButtonStyle {
    var minimumSize: CGFloat = 42

    func makeBody(configuration: Configuration) -> some View {
        InkSeedNodeFrameButtonBody(
            configuration: configuration,
            variant: .compact,
            minimumHeight: minimumSize,
            forceSquare: true
        )
    }
}

private struct InkSeedNodeFrameButtonBody: View {
    enum Variant {
        case primary(accent: Color, showsBackground: Bool)
        case secondary
        case compact
    }

    let configuration: ButtonStyle.Configuration
    let variant: Variant
    let minimumHeight: CGFloat
    var forceSquare: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, forceSquare ? 10 : 20)
            .padding(.vertical, forceSquare ? 8 : 10)
            .frame(minWidth: forceSquare ? minimumHeight : nil)
            .frame(minHeight: minimumHeight)
            .background(frameBackground)
            .overlay(
                InkSeedNodeFrame(
                    color: frameColor,
                    glowColor: glowColor,
                    isDashed: !isEnabled,
                    emphasized: configuration.isPressed && isEnabled,
                    nodeDiameter: forceSquare ? 7.2 : 8
                )
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .shadow(color: elevatedShadowPrimary.color, radius: elevatedShadowPrimary.radius, x: 0, y: elevatedShadowPrimary.y)
            .shadow(color: elevatedShadowSecondary.color, radius: elevatedShadowSecondary.radius, x: 0, y: elevatedShadowSecondary.y)
            .shadow(color: ambientGlow.color, radius: ambientGlow.radius, x: 0, y: ambientGlow.y)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var frameBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(backgroundColor)
    }

    private var frameColor: Color {
        if !isEnabled { return AppTheme.graphiteInk.opacity(0.26) }
        switch variant {
        case .primary:
            if colorScheme == .dark {
                return .white.opacity(configuration.isPressed ? 0.94 : 0.82)
            } else {
                return AppTheme.graphiteInk.opacity(configuration.isPressed ? 0.9 : 0.78)
            }
        case .secondary:
            if colorScheme == .dark {
                return .white.opacity(configuration.isPressed ? 0.88 : 0.74)
            } else {
                return AppTheme.graphiteInk.opacity(configuration.isPressed ? 0.84 : 0.68)
            }
        case .compact:
            if colorScheme == .dark {
                return .white.opacity(configuration.isPressed ? 0.9 : 0.76)
            } else {
                return AppTheme.graphiteInk.opacity(configuration.isPressed ? 0.88 : 0.72)
            }
        }
    }

    private var foregroundColor: Color {
        if !isEnabled { return AppTheme.graphiteInk.opacity(0.45) }
        switch variant {
        case .primary:
            return colorScheme == .dark ? .white.opacity(0.96) : AppTheme.graphiteInk.opacity(0.94)
        case .secondary:
            return colorScheme == .dark ? .white.opacity(0.9) : AppTheme.graphiteInk.opacity(0.92)
        case .compact:
            return colorScheme == .dark ? .white.opacity(0.92) : AppTheme.graphiteInk.opacity(0.9)
        }
    }

    private var backgroundColor: Color {
        if !isEnabled { return .clear }
        switch variant {
        case .primary(let accent, let showsBackground):
            // Keep the node-line frame language, but remove filled interiors.
            guard showsBackground else { return .clear }
            let pressOpacity: CGFloat = colorScheme == .dark ? 0.035 : 0.025
            return accent.opacity(configuration.isPressed ? pressOpacity : 0)
        case .secondary:
            return (colorScheme == .dark ? Color.white : AppTheme.graphiteInk)
                .opacity(configuration.isPressed ? 0.03 : 0)
        case .compact:
            return (colorScheme == .dark ? Color.white : AppTheme.graphiteInk)
                .opacity(configuration.isPressed ? 0.03 : 0)
        }
    }

    private var glowColor: Color {
        if !isEnabled { return .clear }
        switch variant {
        case .primary:
            if colorScheme == .dark {
                return Color(hex: 0xF1E9DB).opacity(0.26)
            } else {
                return AppTheme.graphiteInk.opacity(0.08)
            }
        case .secondary:
            return .clear
        case .compact:
            return .clear
        }
    }

    private var pressFactor: CGFloat {
        configuration.isPressed && isEnabled ? 0.55 : 1
    }

    private var elevatedShadowPrimary: (color: Color, radius: CGFloat, y: CGFloat) {
        guard isEnabled else { return (.clear, 0, 0) }
        switch variant {
        case .primary:
            if colorScheme == .dark {
                return (.black.opacity(0.28 * pressFactor), 12, 5)
            } else {
                return (.black.opacity(0.08 * pressFactor), 12, 6)
            }
        case .secondary:
            return (.black.opacity((colorScheme == .dark ? 0.14 : 0.05) * pressFactor), 6, 3)
        case .compact:
            return (.black.opacity((colorScheme == .dark ? 0.12 : 0.04) * pressFactor), 5, 2.5)
        }
    }

    private var elevatedShadowSecondary: (color: Color, radius: CGFloat, y: CGFloat) {
        guard isEnabled else { return (.clear, 0, 0) }
        switch variant {
        case .primary:
            if colorScheme == .dark {
                return (.black.opacity(0.14 * pressFactor), 7, 2.5)
            } else {
                return (.white.opacity(0.24 * pressFactor), 4, 0.8)
            }
        case .secondary:
            return (.white.opacity((colorScheme == .dark ? 0.08 : 0.14) * pressFactor), 2.5, 0.3)
        case .compact:
            return (.white.opacity((colorScheme == .dark ? 0.06 : 0.12) * pressFactor), 2.0, 0.2)
        }
    }

    private var ambientGlow: (color: Color, radius: CGFloat, y: CGFloat) {
        guard isEnabled else { return (.clear, 0, 0) }
        switch variant {
        case .primary(let accent, _):
            if colorScheme == .dark {
                return (accent.opacity(0.22 * pressFactor), 10, 0)
            } else {
                return (accent.opacity(0.1 * pressFactor), 6, 0)
            }
        case .secondary, .compact:
            return (.clear, 0, 0)
        }
    }
}

private struct InkSeedNodeFrame: View {
    let color: Color
    let glowColor: Color
    let isDashed: Bool
    let emphasized: Bool
    let nodeDiameter: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let padX: CGFloat = 12
            let padY: CGFloat = 8
            let leftX = padX
            let rightX = proxy.size.width - padX
            let topY = padY
            let bottomY = proxy.size.height - padY
            let curve: CGFloat = emphasized ? 3.8 : 2.7

            Path { path in
                path.move(to: CGPoint(x: leftX, y: topY))
                path.addQuadCurve(
                    to: CGPoint(x: rightX, y: topY),
                    control: CGPoint(x: proxy.size.width * 0.5, y: topY - curve)
                )
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: emphasized ? 1.9 : 1.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: isDashed ? [4, 3] : []
                )
            )

            Path { path in
                path.move(to: CGPoint(x: leftX, y: bottomY))
                path.addQuadCurve(
                    to: CGPoint(x: rightX, y: bottomY),
                    control: CGPoint(x: proxy.size.width * 0.5, y: bottomY + curve)
                )
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: emphasized ? 1.9 : 1.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: isDashed ? [4, 3] : []
                )
            )

            Path { path in
                path.move(to: CGPoint(x: leftX, y: topY))
                path.addQuadCurve(
                    to: CGPoint(x: leftX, y: bottomY),
                    control: CGPoint(x: leftX - curve * 0.45, y: proxy.size.height * 0.5)
                )
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: emphasized ? 1.8 : 1.4,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: isDashed ? [4, 3] : []
                )
            )

            Path { path in
                path.move(to: CGPoint(x: rightX, y: topY))
                path.addQuadCurve(
                    to: CGPoint(x: rightX, y: bottomY),
                    control: CGPoint(x: rightX + curve * 0.45, y: proxy.size.height * 0.5)
                )
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: emphasized ? 1.8 : 1.4,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: isDashed ? [4, 3] : []
                )
            )

            cornerNode(at: CGPoint(x: leftX, y: topY))
            cornerNode(at: CGPoint(x: rightX, y: topY))
            cornerNode(at: CGPoint(x: leftX, y: bottomY))
            cornerNode(at: CGPoint(x: rightX, y: bottomY))
        }
        .allowsHitTesting(false)
    }

    private func cornerNode(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(emphasized ? 0.95 : 0))
                .frame(width: nodeDiameter + 6, height: nodeDiameter + 6)
            Circle()
                .stroke(color, lineWidth: emphasized ? 1.8 : 1.4)
                .frame(width: nodeDiameter, height: nodeDiameter)
            Circle()
                .fill(color.opacity(emphasized ? 0.35 : 0.2))
                .frame(width: nodeDiameter * 0.24, height: nodeDiameter * 0.24)
                .offset(x: -nodeDiameter * 0.14, y: -nodeDiameter * 0.14)
        }
        .position(point)
    }
}
