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
                let projectedEdges = layout.projectedTrimmedEdges(nodeRadius: 7)
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
                    let result = PaintRegionDetector.detectRegion(
                        tap: point,
                        layout: layout,
                        existingFills: fills
                    )
                    switch result {
                    case .filled(let region):
                        withAnimation(.easeOut(duration: 0.28)) {
                            fills.append(PaintFillRegion(cells: region, color: color))
                        }
                    case .rejected(let reason):
                        if let message = rejectionMessage(for: reason) {
                            showTransientStatus(message)
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
            return [
                Color(hex: 0xFF6B6B),
                Color(hex: 0x00B894),
                Color(hex: 0x4D96FF),
                Color(hex: 0xFFD93D),
                Color(hex: 0xFF922B),
                Color(hex: 0xD633B8)
            ]
        }
        return [
            Color(hex: 0xA77E58),
            Color(hex: 0x5E7F63),
            Color(hex: 0x6A89B8),
            Color(hex: 0x8C6FA8),
            Color(hex: 0xB5704A),
            Color(hex: 0x4F8C88)
        ]
    }

    private var fillOpacity: Double {
        isJuniorPalette ? 0.68 : 0.54
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
            context.fill(Path(rect), with: .color(fill.color.opacity(fillOpacity)))
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
        let projectedEdges = layout.projectedTrimmedEdges(nodeRadius: 7)
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
                cg.setFillColor(UIColor(fill.color).withAlphaComponent(CGFloat(fillOpacity)).cgColor)
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

    private func rejectionMessage(for reason: PaintRegionDetector.RejectionReason) -> String? {
        switch reason {
        case .tapOutsideBoard:
            return "Tap inside the board"
        case .alreadyFilled:
            return "This area is already filled"
        case .openRegion:
            return "Area edge is open"
        case .openThroughGap:
            return "Try tapping deeper inside the area"
        case .tooSmall:
            return "Area is too small to fill"
        case .blockedSeed:
            return nil
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
    let gridWidth = 240
    let gridHeight = 240

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

    func projectedTrimmedEdges(nodeRadius: CGFloat) -> [[CGPoint]] {
        let projectedByDotID = Dictionary(uniqueKeysWithValues: dots.map { ($0.id, project($0.position)) })
        return edges.map { edge in
            let projected = edge.points.map(project)
            return trimmedPolylineForNodeBoundaries(
                points: projected,
                startDotID: edge.startDotID,
                endDotID: edge.endDotID,
                dotsByID: projectedByDotID,
                nodeRadius: nodeRadius
            )
        }
    }

    var projectedDots: [CGPoint] {
        dots.map { project($0.position) }
    }

    var boardRect: CGRect {
        let bounds = contentRect
        let inset: CGFloat = 18
        let target = CGRect(
            x: inset,
            y: inset,
            width: max(1, size.width - inset * 2),
            height: max(1, size.height - inset * 2)
        )
        let sx = target.width / bounds.width
        let sy = target.height / bounds.height
        let scale = min(sx, sy)
        let mappedWidth = bounds.width * scale
        let mappedHeight = bounds.height * scale
        return CGRect(
            x: target.midX - mappedWidth * 0.5,
            y: target.midY - mappedHeight * 0.5,
            width: mappedWidth,
            height: mappedHeight
        )
    }

    func project(_ point: CGPoint) -> CGPoint {
        let bounds = contentRect
        let target = boardRect
        let sx = target.width / bounds.width
        let sy = target.height / bounds.height
        let scale = min(sx, sy)
        let offsetX = target.midX - (bounds.midX * scale)
        let offsetY = target.midY - (bounds.midY * scale)
        return CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
    }

    private func trimmedPolylineForNodeBoundaries(
        points: [CGPoint],
        startDotID: UUID,
        endDotID: UUID,
        dotsByID: [UUID: CGPoint],
        nodeRadius: CGFloat
    ) -> [CGPoint] {
        guard points.count > 1 else { return points }
        guard let startDot = dotsByID[startDotID],
              let endDot = dotsByID[endDotID] else {
            return points
        }

        let startTrimmed = trimFromStart(points: points, center: startDot, radius: nodeRadius)
        let endTrimmed = trimFromEnd(points: startTrimmed, center: endDot, radius: nodeRadius)
        return endTrimmed.count > 1 ? endTrimmed : points
    }

    private func trimFromStart(points: [CGPoint], center: CGPoint, radius: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        var result = points
        var scan = 0
        while scan < result.count - 1 {
            let a = result[scan]
            let b = result[scan + 1]
            let da = hypot(a.x - center.x, a.y - center.y)
            let db = hypot(b.x - center.x, b.y - center.y)

            if da <= radius, db > radius {
                let denom = max(db - da, 0.0001)
                let t = min(max((radius - da) / denom, 0), 1)
                let boundary = CGPoint(
                    x: a.x + (b.x - a.x) * t,
                    y: a.y + (b.y - a.y) * t
                )
                result[scan] = boundary
                return Array(result[scan...])
            }
            scan += 1
        }
        return points
    }

    private func trimFromEnd(points: [CGPoint], center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let reversed = Array(points.reversed())
        let trimmed = trimFromStart(points: reversed, center: center, radius: radius)
        return Array(trimmed.reversed())
    }
}

private enum PaintRegionDetector {
    private enum PaintDetectionProfile {
        case balanced
        case forgiving

        var closingRadiusCells: Int {
            switch self {
            case .balanced: return 2
            case .forgiving: return 3
            }
        }

        var maxBridgeGapCells: Int {
            switch self {
            case .balanced: return 5
            case .forgiving: return 7
            }
        }

        var tinyLeakBoundaryCellThreshold: Int {
            switch self {
            case .balanced: return 10
            case .forgiving: return 18
            }
        }
    }

    // Internal debug flag for local diagnostics during tuning.
    private static let debugLoggingEnabled = false
    private static let activeProfile: PaintDetectionProfile = .forgiving

    enum RejectionReason {
        case tapOutsideBoard
        case blockedSeed
        case alreadyFilled
        case openRegion
        case openThroughGap
        case tooSmall
    }

    enum DetectionResult {
        case filled(Set<Int>)
        case rejected(RejectionReason)
    }

    static func detectRegion(
        tap: CGPoint,
        layout: PaintBoardLayout,
        existingFills: [PaintFillRegion]
    ) -> DetectionResult {
        guard layout.boardRect.contains(tap) else {
            debugLog("Region rejected: tap outside board")
            return .rejected(.tapOutsideBoard)
        }

        let blocked = buildBlockedMask(layout: layout)
        var blockedOrUsed = blocked
        var usedCells = Set<Int>()
        for fill in existingFills {
            for idx in fill.cells where idx >= 0 && idx < blockedOrUsed.count {
                blockedOrUsed[idx] = true
                usedCells.insert(idx)
            }
        }

        let cellSize = layout.cellSize
        let col = Int((tap.x / cellSize).rounded(.down))
        let row = Int((tap.y / cellSize).rounded(.down))
        guard row >= 0, row < layout.gridHeight, col >= 0, col < layout.gridWidth else {
            debugLog("Region rejected: tap outside grid bounds")
            return .rejected(.tapOutsideBoard)
        }
        let start = row * layout.gridWidth + col
        if usedCells.contains(start) {
            debugLog("Region rejected: already filled")
            return .rejected(.alreadyFilled)
        }
        guard !blockedOrUsed[start] else {
            debugLog("Region rejected: tap on blocked area")
            return .rejected(.blockedSeed)
        }

        var queue: [Int] = [start]
        var queueIndex = 0
        var visited = Set<Int>()
        visited.reserveCapacity(400)
        var openToOutside = false
        var boundaryTouches = 0

        while queueIndex < queue.count {
            let idx = queue[queueIndex]
            queueIndex += 1
            guard !visited.contains(idx) else { continue }
            visited.insert(idx)

            let r = idx / layout.gridWidth
            let c = idx % layout.gridWidth
            if r == 0 || c == 0 || r == layout.gridHeight - 1 || c == layout.gridWidth - 1 {
                openToOutside = true
                boundaryTouches += 1
            }

            let neighbors = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
            for (nr, nc) in neighbors where nr >= 0 && nc >= 0 && nr < layout.gridHeight && nc < layout.gridWidth {
                let nidx = nr * layout.gridWidth + nc
                if !blockedOrUsed[nidx] && !visited.contains(nidx) {
                    queue.append(nidx)
                }
            }
        }

        guard !visited.isEmpty else { return .rejected(.blockedSeed) }
        if openToOutside {
            if boundaryTouches <= activeProfile.tinyLeakBoundaryCellThreshold {
                debugLog("Region rejected: open through tiny gap (\(boundaryTouches) boundary touches)")
                return .rejected(.openThroughGap)
            }
            debugLog("Region rejected: open region (\(boundaryTouches) boundary touches)")
            return .rejected(.openRegion)
        }
        if visited.count < 18 {
            debugLog("Region rejected: too small (\(visited.count) cells)")
            return .rejected(.tooSmall)
        }
        return .filled(visited)
    }

    private static func buildBlockedMask(layout: PaintBoardLayout) -> [Bool] {
        var mask = Array(repeating: false, count: layout.gridWidth * layout.gridHeight)
        let cellSize = layout.cellSize
        // Keep mask slightly wider than rendered geometry to prevent micro-gaps.
        let edgeVisualWidth: CGFloat = 3.35
        let edgeSafetyMargin: CGFloat = 2.1
        let nodeOuterRadius: CGFloat = 7.0
        let nodeSafetyMargin: CGFloat = 3.0
        let junctionSealRadius: CGFloat = 4.6

        let lineRadiusCells = max(2, Int((((edgeVisualWidth * 0.5) + edgeSafetyMargin) / cellSize).rounded(.up)))
        let dotRadiusCells = max(3, Int(((nodeOuterRadius + nodeSafetyMargin) / cellSize).rounded(.up)))
        let junctionRadiusCells = max(dotRadiusCells, Int((junctionSealRadius / cellSize).rounded(.up)))

        for edge in layout.projectedTrimmedEdges(nodeRadius: 7) {
            guard edge.count > 1 else { continue }
            for segment in zip(edge, edge.dropFirst()) {
                rasterSegment(segment.0, segment.1, radiusCells: lineRadiusCells, layout: layout, mask: &mask)
            }
            if let first = edge.first {
                rasterDisk(center: first, radiusCells: junctionRadiusCells, layout: layout, mask: &mask)
            }
            if let last = edge.last {
                rasterDisk(center: last, radiusCells: junctionRadiusCells, layout: layout, mask: &mask)
            }
        }

        for dot in layout.projectedDots {
            rasterDisk(center: dot, radiusCells: dotRadiusCells, layout: layout, mask: &mask)
        }

        // Paint Assist:
        // 1) close tiny 1-3 cell leaks with controlled morphological closing
        // 2) connect very near blocked islands through tiny bridges
        mask = applyClosing(mask: mask, layout: layout, radius: activeProfile.closingRadiusCells)
        applySmallGapBridges(mask: &mask, layout: layout, maxGap: activeProfile.maxBridgeGapCells)

        return mask
    }

    private static func applyClosing(mask: [Bool], layout: PaintBoardLayout, radius: Int) -> [Bool] {
        let dilated = dilate(mask: mask, layout: layout, radius: radius)
        return erode(mask: dilated, layout: layout, radius: radius)
    }

    private static func dilate(mask: [Bool], layout: PaintBoardLayout, radius: Int) -> [Bool] {
        guard radius > 0 else { return mask }
        var out = Array(repeating: false, count: mask.count)
        for row in 0..<layout.gridHeight {
            for col in 0..<layout.gridWidth {
                let idx = row * layout.gridWidth + col
                if !mask[idx] { continue }
                for rr in max(0, row - radius)...min(layout.gridHeight - 1, row + radius) {
                    for cc in max(0, col - radius)...min(layout.gridWidth - 1, col + radius) {
                        let dr = rr - row
                        let dc = cc - col
                        if dr * dr + dc * dc <= radius * radius {
                            out[rr * layout.gridWidth + cc] = true
                        }
                    }
                }
            }
        }
        return out
    }

    private static func erode(mask: [Bool], layout: PaintBoardLayout, radius: Int) -> [Bool] {
        guard radius > 0 else { return mask }
        var out = Array(repeating: false, count: mask.count)
        for row in 0..<layout.gridHeight {
            for col in 0..<layout.gridWidth {
                let idx = row * layout.gridWidth + col
                guard mask[idx] else { continue }
                var keep = true
                for rr in max(0, row - radius)...min(layout.gridHeight - 1, row + radius) {
                    for cc in max(0, col - radius)...min(layout.gridWidth - 1, col + radius) {
                        let dr = rr - row
                        let dc = cc - col
                        if dr * dr + dc * dc > radius * radius { continue }
                        if !mask[rr * layout.gridWidth + cc] {
                            keep = false
                            break
                        }
                    }
                    if !keep { break }
                }
                out[idx] = keep
            }
        }
        return out
    }

    private static func applySmallGapBridges(mask: inout [Bool], layout: PaintBoardLayout, maxGap: Int) {
        guard maxGap >= 2 else { return }
        let width = layout.gridWidth
        let height = layout.gridHeight

        // Horizontal bridges
        for row in 1..<(height - 1) {
            for col in 1..<(width - 1 - maxGap) {
                let left = row * width + col
                if !mask[left] { continue }
                for gap in 2...maxGap {
                    let rightCol = col + gap
                    let right = row * width + rightCol
                    guard rightCol < width - 1 else { continue }
                    if !mask[right] { continue }
                    let betweenRange = (col + 1)..<rightCol
                    let allGap = betweenRange.allSatisfy { !mask[row * width + $0] }
                    if allGap {
                        for bridgeCol in betweenRange {
                            mask[row * width + bridgeCol] = true
                        }
                    }
                }
            }
        }

        // Vertical bridges
        for col in 1..<(width - 1) {
            for row in 1..<(height - 1 - maxGap) {
                let top = row * width + col
                if !mask[top] { continue }
                for gap in 2...maxGap {
                    let bottomRow = row + gap
                    guard bottomRow < height - 1 else { continue }
                    let bottom = bottomRow * width + col
                    if !mask[bottom] { continue }
                    let betweenRange = (row + 1)..<bottomRow
                    let allGap = betweenRange.allSatisfy { !mask[$0 * width + col] }
                    if allGap {
                        for bridgeRow in betweenRange {
                            mask[bridgeRow * width + col] = true
                        }
                    }
                }
            }
        }
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

    private static func debugLog(_ message: String) {
        guard debugLoggingEnabled else { return }
        print("[PaintAssist] \(message)")
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
