import SwiftUI

enum SplashDurationPreset {
    case short
    case balanced
    case cinematic

    var totalDuration: Double {
        switch self {
        case .short: return 1.6
        case .balanced: return 5.5
        case .cinematic: return 2.4
        }
    }
}

struct InkSeedLogoSymbol: View {
    @Environment(\.colorScheme) private var colorScheme
    var firstSegmentProgress: CGFloat = 1
    var secondSegmentProgress: CGFloat = 1
    var leftNodeScale: CGFloat = 1
    var middleNodeScale: CGFloat = 1
    var rightNodeScale: CGFloat = 1
    var accentOpacity: CGFloat = 0.18
    var useAccentMiddleNode: Bool = false
    var reducedAccent: Bool = false

    var body: some View {
        ZStack {
            // Subtle premium accent echo for the full freehand trajectory.
            Path { path in
                path.move(to: CGPoint(x: 18, y: 26))
                path.addQuadCurve(to: CGPoint(x: 66, y: 33), control: CGPoint(x: 40, y: 20))
                path.addQuadCurve(to: CGPoint(x: 112, y: 30), control: CGPoint(x: 87, y: 41))
            }
            .trim(from: 0, to: max(firstSegmentProgress, secondSegmentProgress))
            .stroke(AppTheme.royalPurple.opacity(accentOpacity), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            // Segment 1: left -> middle
            Path { path in
                path.move(to: CGPoint(x: 18, y: 26))
                path.addQuadCurve(to: CGPoint(x: 66, y: 33), control: CGPoint(x: 40, y: 20))
            }
            .trim(from: 0, to: firstSegmentProgress)
            .stroke(AppTheme.graphiteInk.opacity(0.92), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Segment 2: middle -> right
            Path { path in
                path.move(to: CGPoint(x: 66, y: 33))
                path.addQuadCurve(to: CGPoint(x: 112, y: 30), control: CGPoint(x: 87, y: 41))
            }
            .trim(from: 0, to: secondSegmentProgress)
            .stroke(AppTheme.graphiteInk.opacity(0.92), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            Circle()
                .stroke(AppTheme.graphiteInk.opacity(0.9), lineWidth: 2)
                .frame(width: 18, height: 18)
                .position(x: 18, y: 26)
                .scaleEffect(leftNodeScale)

            if useAccentMiddleNode {
                Circle()
                    .fill(middleNodeAccentColor.opacity(reducedAccent ? 0.16 : 0.2))
                    .frame(width: reducedAccent ? 17 : 19, height: reducedAccent ? 17 : 19)
                    .position(x: 66, y: 33)
                    .blur(radius: reducedAccent ? 2.6 : 3.4)
                    .scaleEffect(middleNodeScale)
            }

            Circle()
                .stroke(useAccentMiddleNode ? middleNodeAccentColor.opacity(reducedAccent ? 0.82 : 0.96) : AppTheme.graphiteInk.opacity(0.88), lineWidth: 1.7)
                .frame(width: 13, height: 13)
                .position(x: 66, y: 33)
                .scaleEffect(middleNodeScale)

            Circle()
                .stroke(AppTheme.graphiteInk.opacity(0.86), lineWidth: 1.5)
                .frame(width: 10, height: 10)
                .position(x: 112, y: 30)
                .scaleEffect(rightNodeScale)
        }
        .frame(width: 132, height: 58)
    }

    private var middleNodeAccentColor: Color {
        if colorScheme == .dark {
            return Color(hex: 0xF4A261)
        }
        return Color(hex: 0x9D42F0)
    }
}

struct InkSeedSplashView: View {
    var onFinished: () -> Void
    var durationPreset: SplashDurationPreset = .balanced

    @State private var showLeftNode = false
    @State private var firstSegmentProgress: CGFloat = 0
    @State private var showMiddleNode = false
    @State private var secondSegmentProgress: CGFloat = 0
    @State private var showRightNode = false
    @State private var showWordmark = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            AppTheme.paperBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                InkSeedLogoSymbol(
                    firstSegmentProgress: firstSegmentProgress,
                    secondSegmentProgress: secondSegmentProgress,
                    leftNodeScale: showLeftNode ? 1 : 0.6,
                    middleNodeScale: showMiddleNode ? 1 : 0.6,
                    rightNodeScale: showRightNode ? 1 : 0.6,
                    accentOpacity: showWordmark ? 0.2 : 0.1
                )
                .opacity(showLeftNode ? 1 : 0)

                VStack(spacing: 8) {
                    Text(L10n.t("splash.wordmark"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .tracking(7)
                        .foregroundStyle(AppTheme.graphiteInk.opacity(0.95))
                        .opacity(showWordmark ? 1 : 0)

                    Text(L10n.t("welcome.tagline"))
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.graphiteInk.opacity(0.62))
                        .opacity(showTagline ? 1 : 0)
                }
            }
        }
        .onAppear {
            animateSequence()
        }
    }

    private func animateSequence() {
        let total = durationPreset.totalDuration
        let nodeInDuration = total * 0.11
        let firstLineDrawDuration = total * 0.18
        let middleNodeDuration = total * 0.1
        let secondLineDrawDuration = total * 0.14
        let rightNodeDuration = total * 0.09
        let wordmarkDuration = total * 0.15
        let taglineDuration = total * 0.15

        let firstLineStart = total * 0.12
        let middleNodeStart = total * 0.31
        let secondLineStart = total * 0.43
        let rightNodeStart = total * 0.56
        let wordmarkStart = total * 0.66
        let taglineStart = total * 0.76

        withAnimation(.spring(response: nodeInDuration, dampingFraction: 0.88, blendDuration: 0.04)) {
            showLeftNode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + firstLineStart) {
            withAnimation(.timingCurve(0.24, 0.82, 0.26, 1, duration: firstLineDrawDuration)) {
                firstSegmentProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + middleNodeStart) {
            withAnimation(.spring(response: middleNodeDuration, dampingFraction: 0.9, blendDuration: 0.04)) {
                showMiddleNode = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + secondLineStart) {
            withAnimation(.timingCurve(0.22, 0.8, 0.28, 1, duration: secondLineDrawDuration)) {
                secondSegmentProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + rightNodeStart) {
            withAnimation(.spring(response: rightNodeDuration, dampingFraction: 0.9, blendDuration: 0.04)) {
                showRightNode = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + wordmarkStart) {
            withAnimation(.easeOut(duration: wordmarkDuration)) {
                showWordmark = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + taglineStart) {
            withAnimation(.easeOut(duration: taglineDuration)) {
                showTagline = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            onFinished()
        }
    }
}
