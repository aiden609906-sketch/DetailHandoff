import SwiftUI
import UIKit

struct WorkflowScrollOffsetObserver: UIViewRepresentable {
    @Binding var horizontalOffset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(horizontalOffset: $horizontalOffset)
    }

    func makeUIView(context: Context) -> WorkflowScrollAttachmentView {
        let view = WorkflowScrollAttachmentView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.onHierarchyChange = { [weak coordinator = context.coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.attachIfNeeded(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: WorkflowScrollAttachmentView, context: Context) {
        context.coordinator.horizontalOffset = $horizontalOffset
        context.coordinator.attachIfNeeded(from: uiView)
    }

    static func dismantleUIView(_ uiView: WorkflowScrollAttachmentView, coordinator: Coordinator) {
        uiView.onHierarchyChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        var horizontalOffset: Binding<CGFloat>

        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?

        init(horizontalOffset: Binding<CGFloat>) {
            self.horizontalOffset = horizontalOffset
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            scrollView = nil
        }

        func attachIfNeeded(from view: UIView) {
            guard let enclosingScrollView = view.enclosingScrollView else { return }
            guard enclosingScrollView !== scrollView else { return }

            contentOffsetObservation?.invalidate()
            scrollView = enclosingScrollView
            contentOffsetObservation = enclosingScrollView.observe(
                \.contentOffset,
                options: [.initial, .new]
            ) { [weak self] scrollView, _ in
                let offset = max(scrollView.contentOffset.x, 0)
                Task { @MainActor in
                    self?.horizontalOffset.wrappedValue = offset
                }
            }
        }
    }
}

final class WorkflowScrollAttachmentView: UIView {
    var onHierarchyChange: (() -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        onHierarchyChange?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onHierarchyChange?()
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var candidate = superview
        while let current = candidate {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            candidate = current.superview
        }
        return nil
    }
}
