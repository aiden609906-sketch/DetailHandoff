import SwiftUI

struct SignaturePad: View {
    @Binding var strokes: [SignatureStroke]
    @State private var activeStrokeIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for stroke in strokes where stroke.points.count > 1 {
                    var path = Path()
                    let first = stroke.points[0]
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                    context.stroke(path, with: .color(.primary), lineWidth: 2.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in append(point: normalizedPoint(value.location, in: geometry.size)) }
                    .onEnded { _ in activeStrokeIndex = nil }
            )
        }
        .frame(height: 180)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.secondary.opacity(0.35)))
        .accessibilityLabel("Signature drawing area")
    }

    private func normalizedPoint(_ location: CGPoint, in size: CGSize) -> SignaturePoint {
        SignaturePoint(
            x: min(max(location.x / max(size.width, 1), 0), 1),
            y: min(max(location.y / max(size.height, 1), 0), 1)
        )
    }

    private func append(point: SignaturePoint) {
        guard point.x.isFinite, point.y.isFinite else { return }
        if let activeStrokeIndex {
            strokes[activeStrokeIndex].points.append(point)
        } else {
            strokes.append(SignatureStroke(points: [point]))
            activeStrokeIndex = strokes.indices.last
        }
    }
}
