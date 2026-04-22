import SwiftUI

struct GameView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var interactionState = BoardInteractionState()
    @State private var showHelp = false
    @State private var showSplash = true
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
                Text("INKSEED")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .tracking(6.4)
                    .foregroundStyle(AppTheme.graphiteInk.opacity(0.88))
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
        VStack(spacing: 16) {
            topBar

            BoardView(gameState: gameState, interactionState: interactionState)
                .frame(maxWidth: 980, maxHeight: 700)
                .padding(.horizontal, 24)

            if gameState.flowState == .setup {
                setupFooter
            } else {
                playerFooter
            }
        }
        .padding(.vertical, 20)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
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

            Spacer()
        }
        .padding(.horizontal, 24)
        .tint(AppTheme.royalPurple)
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
        .padding(.horizontal, 24)
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

            Spacer()
            
            if let winner = gameState.winner {
                Text("\(winner.title) wins")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.royalPurple.opacity(0.16), in: Capsule())
            }
        }
        .padding(.horizontal, 24)
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
}

#Preview {
    GameView()
}
