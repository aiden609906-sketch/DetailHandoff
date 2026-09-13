import PDFKit
import SwiftUI
import UIKit

struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFPreviewContainer {
        let container = PDFPreviewContainer()
        container.show(data: data)
        return container
    }

    func updateUIView(_ uiView: PDFPreviewContainer, context: Context) {
        uiView.show(data: data)
    }
}

final class PDFPreviewContainer: UIView {
    private let pdfView = PDFView()
    private let errorLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.displayMode = .singlePageContinuous

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "The PDF could not be displayed."
        errorLabel.textAlignment = .center
        errorLabel.textColor = .secondaryLabel
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        addSubview(pdfView)
        addSubview(errorLabel)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(data: Data) {
        pdfView.document = PDFDocument(data: data)
        let failed = pdfView.document == nil
        pdfView.isHidden = failed
        errorLabel.isHidden = !failed
    }
}
