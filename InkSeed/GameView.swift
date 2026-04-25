import SwiftUI

struct GameView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var interactionState = BoardInteractionState()
    @State private var showHelp = false
    @State private var showPaintMatch = false
    @State private var showSplash = true
    @State private var isBottomBarCollapsed = false
    @State private var prefersDarkTheme = false
    @State private var modeSelection = 0
    private let splashPreset: SplashDurationPreset = .balanced

    var body: some View {
        ZStack {
            AppTheme.paperBackground.ignoresSafeArea()

            if showSplash {
                InkSeedSplashView(onFinished: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSplash = false
                    }
                }, durationPreset: splashPreset)
                .transition(.opacity)
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
        .sheet(isPresented: $showPaintMatch) {
            PaintMatchView(
                edges: gameState.edges,
                dots: gameState.dots,
                isJuniorPalette: false
            )
        }
        .preferredColorScheme(prefersDarkTheme ? .dark : .light)
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                InkSeedLogoSymbol()
                    .frame(height: 64)
                    .padding(.bottom, 6)
                Text("InkSeed")
                    .font(.system(size: 60, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.graphiteInk.opacity(0.95))
                Text("Calm strategy through drawing.")
                    .font(.title3)
                    .foregroundStyle(AppTheme.graphiteInk.opacity(0.62))
                Text("Every move plants a possibility.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .tracking(0.55)
                    .foregroundStyle(AppTheme.graphiteInk.opacity(0.52))
            }

            Button {
                gameState.startNewGame()
            } label: {
                Text("New Game")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 34)
                    .padding(.vertical, 14)
                    .background(AppTheme.royalPurple, in: Capsule())
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding()
    }

    private var gameSurface: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 10) {
                topBar

                BoardView(gameState: gameState, interactionState: interactionState)
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
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button("New Game") {
                    gameState.startNewGame()
                }
                .buttonStyle(.bordered)

                Button("Restart") {
                    gameState.restartPlay()
                }
                .buttonStyle(.bordered)

                Button("Help") {
                    showHelp = true
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            InkSeedLogoSymbol()
                .frame(width: 34, height: 16)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.paperSecondary.opacity(0.72), in: Capsule())

            Spacer()

            HStack(spacing: 8) {
                Picker("", selection: $modeSelection) {
                    Text("Premium").tag(0)
                    Text("Junior").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Button {
                    prefersDarkTheme.toggle()
                } label: {
                    Image(systemName: prefersDarkTheme ? "sun.max" : "moon")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .tint(AppTheme.royalPurple)
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
            Text("Setup: place 3-6 starting dots with Apple Pencil.")
                .font(.headline)
                .foregroundStyle(AppTheme.graphiteInk.opacity(0.75))

            Text("\(gameState.dots.count)/\(gameState.maxSetupDots)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.graphiteInk.opacity(0.6))

            Button("Undo") {
                gameState.removeLastSetupDot()
            }
            .buttonStyle(.bordered)
            .disabled(gameState.dots.isEmpty)

            Button("Start Play") {
                gameState.finalizeSetupIfPossible()
            }
            .buttonStyle(.borderedProminent)
            .disabled(gameState.dots.count < gameState.minSetupDots)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.paperSecondary.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .tint(AppTheme.royalPurple)
    }

    private var playerFooter: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(gameState.currentPlayer == .one ? AppTheme.royalPurple : AppTheme.graphiteInk.opacity(0.45))
                .frame(width: 12, height: 12)

            Text("Turn: \(gameState.currentPlayer.title)")
                .font(.headline)
                .foregroundStyle(AppTheme.graphiteInk.opacity(0.8))
            
            Text(phaseHint)
                .font(.subheadline)
                .foregroundStyle(AppTheme.graphiteInk.opacity(0.58))

            Button(modeSelection == 1 ? "Need help?" : "Check moves") {
                checkMovesTapped()
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.royalPurple.opacity(0.86))
            .disabled(gameState.winner != nil || gameState.flowState != .play)

            Spacer()
            
            if let winner = gameState.winner {
                HStack(spacing: 8) {
                    Text("\(winner.title) wins")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.royalPurple.opacity(0.16), in: Capsule())

                    Button("Paint the Match 🎨") {
                        showPaintMatch = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.paperSecondary.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("MVP Rules")
                        .font(.title2.weight(.semibold))
                    Text("• Setup: place 3-6 starting dots.")
                    Text("• Phase A: draw a freehand line between two dots or make a loop.")
                    Text("• The line cannot cross/touch other lines or pass through unrelated dots.")
                    Text("• Phase B: tap a point on the new line to insert a dot there.")
                    Text("• The line splits into two segments and the inserted dot gets degree 2.")
                    Text("• Max degree per dot is 3.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("InkSeed Help")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
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
}

#Preview {
    GameView()
}
