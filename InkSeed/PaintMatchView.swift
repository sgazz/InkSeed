import Photos
import SwiftUI
import UIKit

struct PaintMatchView: View {
    let edges: [EdgeModel]
    let dots: [DotModel]
    let isJuniorPalette: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var selectedColorIndex = 0
    @State private var fills: [PaintFillRegion] = []
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var statusMessage: String?
    @State private var canvasSize: CGSize = CGSize(width: 900, height: 600)

    var body: some View {
        VStack(spacing: 14) {
            Text("Paint the Match 🎨")
                .font(.title2.weight(.semibold))

            GeometryReader { proxy in
                let layout = PaintBoardLayout(size: proxy.size, edges: edges, dots: dots)
                let projectedEdges = layout.projectedEdges
                let projectedDots = layout.projectedDots

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.paperBackground)

                    Canvas { context, _ in
                        for fill in fills {
                            drawFill(fill, in: &context, layout: layout)
                        }
                    }

                    Canvas { context, _ in
                        for edge in projectedEdges {
                            guard let first = edge.first else { continue }
                            var path = Path()
                            path.move(to: first)
                            path.addLines(edge)
                            context.stroke(
                                path,
                                with: .color(AppTheme.graphiteInk.opacity(0.74)),
                                style: StrokeStyle(lineWidth: 3.35, lineCap: .round, lineJoin: .round)
                            )
                        }

                        for dot in projectedDots {
                            let rect = CGRect(x: dot.x - 7, y: dot.y - 7, width: 14, height: 14)
                            context.stroke(
                                Path(ellipseIn: rect),
                                with: .color(AppTheme.graphiteInk.opacity(0.8)),
                                lineWidth: 2
                            )
                        }
                    }
                }
                .background(AppTheme.paperSecondary.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { point in
                    let palette = activePalette
                    guard !palette.isEmpty else { return }
                    let color = palette[min(selectedColorIndex, palette.count - 1)]
                    if let region = PaintRegionDetector.detectRegion(
                        tap: point,
                        layout: layout,
                        existingFills: fills
                    ) {
                        withAnimation(.easeOut(duration: 0.28)) {
                            fills.append(PaintFillRegion(cells: region, color: color))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 500)
            .onAppear {
                canvasSize = CGSize(width: 2200, height: 1500)
            }

            paletteBar
            controlsBar
        }
        .padding(20)
        .background(AppTheme.paperBackground)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .overlay(alignment: .top) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.paperSecondary.opacity(0.92), in: Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 4)
            }
        }
    }

    private var activePalette: [Color] {
        if isJuniorPalette {
            return [AppTheme.juniorCoral, AppTheme.juniorMint, AppTheme.juniorSky, .yellow, .orange, .pink]
        }
        return [Color(hex: 0xC8B6A6), Color(hex: 0x97A97C), Color(hex: 0xA3B8D8), Color(hex: 0xB8A1C9), Color(hex: 0xD8B08C), Color(hex: 0x8BA09A)]
    }

    private var paletteBar: some View {
        HStack(spacing: 10) {
            ForEach(Array(activePalette.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle().stroke(Color.white.opacity(selectedColorIndex == index ? 0.95 : 0), lineWidth: 2)
                    )
                    .onTapGesture {
                        selectedColorIndex = index
                    }
            }
        }
        .padding(.vertical, 4)
    }

    private var controlsBar: some View {
        HStack(spacing: 10) {
            Button("Save") {
                saveArtworkToPhotos()
            }
            .buttonStyle(.borderedProminent)

            Button("Share") {
                let image = renderArtworkImage(size: canvasSize)
                shareItems = [image]
                showShareSheet = true
            }
            .buttonStyle(.bordered)

            Button("Undo") {
                _ = fills.popLast()
            }
            .buttonStyle(.bordered)
            .disabled(fills.isEmpty)

            Button("Clear") {
                withAnimation(.easeOut(duration: 0.2)) {
                    fills.removeAll()
                }
            }
            .buttonStyle(.bordered)
            .disabled(fills.isEmpty)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }

    private func drawFill(_ fill: PaintFillRegion, in context: inout GraphicsContext, layout: PaintBoardLayout) {
        let cellSize = layout.cellSize
        for cell in fill.cells {
            let row = cell / layout.gridWidth
            let col = cell % layout.gridWidth
            let rect = CGRect(
                x: CGFloat(col) * cellSize,
                y: CGFloat(row) * cellSize,
                width: cellSize + 0.2,
                height: cellSize + 0.2
            )
            context.fill(Path(rect), with: .color(fill.color.opacity(0.36)))
        }
    }

    private func saveArtworkToPhotos() {
        let image = renderArtworkImage(size: canvasSize)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    showTransientStatus("Photos permission needed")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                DispatchQueue.main.async {
                    showTransientStatus(success ? "Saved to Photos" : "Save failed")
                }
            }
        }
    }

    private func renderArtworkImage(size: CGSize) -> UIImage {
        let renderSize = CGSize(width: max(2200, size.width), height: max(1500, size.height))
        let layout = PaintBoardLayout(size: renderSize, edges: edges, dots: dots)
        let projectedEdges = layout.projectedEdges
        let projectedDots = layout.projectedDots
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(AppTheme.paperBackground).cgColor)
            cg.fill(CGRect(origin: .zero, size: renderSize))

            // Fills behind lines and nodes.
            let cellSize = layout.cellSize
            for fill in fills {
                cg.setFillColor(UIColor(fill.color).withAlphaComponent(0.36).cgColor)
                for cell in fill.cells {
                    let row = cell / layout.gridWidth
                    let col = cell % layout.gridWidth
                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize + 0.2,
                        height: cellSize + 0.2
                    )
                    cg.fill(rect)
                }
            }

            cg.setStrokeColor(UIColor(AppTheme.graphiteInk).withAlphaComponent(0.74).cgColor)
            cg.setLineWidth(3.35)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)
            for edge in projectedEdges {
                guard let first = edge.first else { continue }
                cg.beginPath()
                cg.move(to: first)
                for point in edge.dropFirst() { cg.addLine(to: point) }
                cg.strokePath()
            }

            cg.setStrokeColor(UIColor(AppTheme.graphiteInk).withAlphaComponent(0.8).cgColor)
            cg.setLineWidth(2)
            for dot in projectedDots {
                let rect = CGRect(x: dot.x - 7, y: dot.y - 7, width: 14, height: 14)
                cg.strokeEllipse(in: rect)
            }
        }
    }

    private func showTransientStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            statusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                statusMessage = nil
            }
        }
    }
}

private struct PaintFillRegion: Identifiable {
    let id = UUID()
    let cells: Set<Int>
    let color: Color
}

private struct PaintBoardLayout {
    let size: CGSize
    let edges: [EdgeModel]
    let dots: [DotModel]
    let gridWidth = 180
    let gridHeight = 180

    var cellSize: CGFloat {
        min(size.width / CGFloat(gridWidth), size.height / CGFloat(gridHeight))
    }

    private var contentRect: CGRect {
        let points = dots.map(\.position) + edges.flatMap(\.points)
        guard !points.isEmpty else { return CGRect(origin: .zero, size: size) }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? size.width
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? size.height
        let width = max(1, maxX - minX)
        let height = max(1, maxY - minY)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    var projectedEdges: [[CGPoint]] {
        edges.map { edge in
            edge.points.map(project)
        }
    }

    var projectedDots: [CGPoint] {
        dots.map { project($0.position) }
    }

    func project(_ point: CGPoint) -> CGPoint {
        let bounds = contentRect
        let inset: CGFloat = 18
        let target = CGRect(x: inset, y: inset, width: max(1, size.width - inset * 2), height: max(1, size.height - inset * 2))
        let sx = target.width / bounds.width
        let sy = target.height / bounds.height
        let scale = min(sx, sy)
        let offsetX = target.midX - (bounds.midX * scale)
        let offsetY = target.midY - (bounds.midY * scale)
        return CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
    }
}

private enum PaintRegionDetector {
    static func detectRegion(
        tap: CGPoint,
        layout: PaintBoardLayout,
        existingFills: [PaintFillRegion]
    ) -> Set<Int>? {
        let blocked = buildBlockedMask(layout: layout)
        var blockedOrUsed = blocked
        for fill in existingFills {
            for idx in fill.cells where idx >= 0 && idx < blockedOrUsed.count {
                blockedOrUsed[idx] = true
            }
        }

        let cellSize = layout.cellSize
        let col = Int((tap.x / cellSize).rounded(.down))
        let row = Int((tap.y / cellSize).rounded(.down))
        guard row >= 0, row < layout.gridHeight, col >= 0, col < layout.gridWidth else { return nil }
        let start = row * layout.gridWidth + col
        guard !blockedOrUsed[start] else { return nil }

        var queue: [Int] = [start]
        var visited = Set<Int>()
        visited.reserveCapacity(400)
        var openToOutside = false

        while !queue.isEmpty {
            let idx = queue.removeFirst()
            guard !visited.contains(idx) else { continue }
            visited.insert(idx)

            let r = idx / layout.gridWidth
            let c = idx % layout.gridWidth
            if r == 0 || c == 0 || r == layout.gridHeight - 1 || c == layout.gridWidth - 1 {
                openToOutside = true
            }

            let neighbors = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
            for (nr, nc) in neighbors where nr >= 0 && nc >= 0 && nr < layout.gridHeight && nc < layout.gridWidth {
                let nidx = nr * layout.gridWidth + nc
                if !blockedOrUsed[nidx] && !visited.contains(nidx) {
                    queue.append(nidx)
                }
            }
        }

        guard !openToOutside, !visited.isEmpty else { return nil }
        return visited
    }

    private static func buildBlockedMask(layout: PaintBoardLayout) -> [Bool] {
        var mask = Array(repeating: false, count: layout.gridWidth * layout.gridHeight)
        let cellSize = layout.cellSize
        let lineRadiusCells = max(1, Int((3.8 / cellSize).rounded(.up)))
        let dotRadiusCells = max(2, Int((9.0 / cellSize).rounded(.up)))

        for edge in layout.projectedEdges {
            guard edge.count > 1 else { continue }
            for segment in zip(edge, edge.dropFirst()) {
                rasterSegment(segment.0, segment.1, radiusCells: lineRadiusCells, layout: layout, mask: &mask)
            }
        }

        for dot in layout.projectedDots {
            rasterDisk(center: dot, radiusCells: dotRadiusCells, layout: layout, mask: &mask)
        }

        return mask
    }

    private static func rasterSegment(
        _ a: CGPoint,
        _ b: CGPoint,
        radiusCells: Int,
        layout: PaintBoardLayout,
        mask: inout [Bool]
    ) {
        let length = hypot(b.x - a.x, b.y - a.y)
        let steps = max(2, Int((length / max(layout.cellSize * 0.5, 0.1)).rounded(.up)))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            rasterDisk(center: p, radiusCells: radiusCells, layout: layout, mask: &mask)
        }
    }

    private static func rasterDisk(
        center: CGPoint,
        radiusCells: Int,
        layout: PaintBoardLayout,
        mask: inout [Bool]
    ) {
        let col = Int((center.x / layout.cellSize).rounded(.down))
        let row = Int((center.y / layout.cellSize).rounded(.down))
        guard row >= 0, row < layout.gridHeight, col >= 0, col < layout.gridWidth else { return }

        for r in (row - radiusCells)...(row + radiusCells) where r >= 0 && r < layout.gridHeight {
            for c in (col - radiusCells)...(col + radiusCells) where c >= 0 && c < layout.gridWidth {
                let dr = r - row
                let dc = c - col
                if dr * dr + dc * dc <= radiusCells * radiusCells {
                    mask[r * layout.gridWidth + c] = true
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
