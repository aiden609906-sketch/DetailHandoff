import Foundation
import ImageIO
import UIKit

enum ReportRendererError: Error, Equatable {
    case unreadableAsset(String)
}

/// Native, offline US Letter renderer. Decodes one bounded image at a time.
@MainActor
enum ReportRenderer {
    static func render(snapshot: ReportSnapshot, number: String, version: Int, sealedAt: Date, media: MediaStore, isDraft: Bool = false) throws -> Data {
        // Validate every referenced original/thumbnail/logo, even assets not drawn in the PDF.
        for path in snapshot.referencedAssetPaths.sorted() {
            try autoreleasepool { _ = try loadImage(path, media: media) }
        }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        var renderError: (any Error)?
        let data = renderer.pdfData { context in
            let canvas = ReportCanvas(context: context, businessName: snapshot.businessName, number: number, version: version, isDraft: isDraft)
            do {
                canvas.newPage()
                canvas.text(isDraft ? "DRAFT - NOT SEALED" : "Vehicle condition report", style: .title)
                canvas.text("\(number) | Version \(version)", style: .heading)
                canvas.text("\(isDraft ? "Preview generated" : "Sealed"): \(timestamp(sealedAt))")
                if let logo = snapshot.logoImagePath {
                    try autoreleasepool { canvas.image(try loadImage(logo, media: media), maximumHeight: 80) }
                }
                canvas.text(snapshot.businessName.isEmpty ? "Business name not provided" : snapshot.businessName, style: .heading)
                canvas.text("Phone: \(snapshot.businessPhone)\nEmail: \(snapshot.businessEmail)")
                canvas.text("Job details", style: .heading)
                canvas.text("Customer: \(snapshot.customerName)\nVehicle: \(snapshot.vehicleLabel)\nPlate: \(snapshot.plate)\nColor: \(snapshot.color)\nService: \(snapshot.serviceName)")
                if let phone = snapshot.customerPhone { canvas.text("Customer phone: \(phone)") }
                if let email = snapshot.customerEmail { canvas.text("Customer email: \(email)") }
                if let location = snapshot.serviceLocation { canvas.text("Service location: \(location)") }
                canvas.text("Job created: \(timestamp(snapshot.createdAt))\nService started: \(timestamp(snapshot.serviceStartedAt))\nService finished: \(timestamp(snapshot.serviceFinishedAt))")
                canvas.text("Notes", style: .heading)
                canvas.text(snapshot.notes.isEmpty ? "None recorded" : snapshot.notes)

                for phase in CapturePhase.allCases {
                    canvas.newPage()
                    let phaseName = phase == .before ? "Before" : "After"
                    canvas.text("\(phaseName) evidence", style: .title)
                    for slot in snapshot.capture.slots {
                        canvas.text("\(phaseName) / \(slot.name)", style: .heading)
                        let photos = snapshot.capture.photos.filter { $0.phase == phase && $0.slotID == slot.id }
                        let skips = snapshot.capture.skips.filter { $0.phase == phase && $0.slotID == slot.id }
                        for skip in skips { canvas.text("Skipped: \(skip.reason)") }
                        if photos.isEmpty && skips.isEmpty { canvas.text("No photo recorded (optional view)") }
                        for photo in photos {
                            // Keep ordinary captions with their image when they fit on one page.
                            canvas.ensureSpace(340)
                            canvas.text("\(phaseName) / \(slot.name)\nPhoto: \(photo.id.uuidString)\nCaptured: \(timestamp(photo.capturedAt))", style: .caption)
                            try autoreleasepool {
                                canvas.image(try loadImage(photo.imagePath, media: media), maximumHeight: 260)
                            }
                        }
                    }
                }

                canvas.newPage()
                canvas.text("Findings", style: .title)
                if snapshot.capture.findings.isEmpty { canvas.text("No findings recorded") }
                for finding in snapshot.capture.findings {
                    let slotName = snapshot.capture.slots.first { $0.id == finding.slotID }?.name ?? finding.slotID
                    canvas.text("\(slotName) / \(finding.kind) / \(finding.severity)", style: .heading)
                    canvas.text(finding.notes.isEmpty ? "No additional notes" : finding.notes)
                    canvas.text("Linked photos: \(finding.photoIDs.map(\.uuidString).joined(separator: ", "))", style: .caption)
                }

                canvas.text("Acknowledgment", style: .title)
                let acknowledgment = snapshot.acknowledgment
                canvas.text(acknowledgment.confirmationText)
                canvas.text("Name: \(acknowledgment.customerName)\nRecorded: \(timestamp(acknowledgment.recordedAt))")
                switch acknowledgment.method {
                case .signature:
                    canvas.text("Customer signature", style: .heading)
                    canvas.signature(acknowledgment.strokes)
                case .customerUnavailable:
                    canvas.text("CUSTOMER UNAVAILABLE - NO SIGNATURE", style: .heading)
                    canvas.text("Reason: \(acknowledgment.unavailableReason)")
                }
                canvas.text("Disclaimer", style: .heading)
                canvas.text(snapshot.disclaimer.isEmpty ? "No business disclaimer provided" : snapshot.disclaimer)
            } catch {
                renderError = error
            }
        }
        if let renderError { throw renderError }
        return data
    }

    private static func loadImage(_ path: String, media: MediaStore) throws -> UIImage {
        let url = try media.url(for: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete else {
            throw ReportRendererError.unreadableAsset(path)
        }
        return UIImage(cgImage: cgImage)
    }

    private static func timestamp(_ date: Date?) -> String {
        guard let date else { return "Not recorded" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter.string(from: date)
    }
}

@MainActor
private final class ReportCanvas {
    enum TextStyle { case title, heading, body, caption }

    private let context: UIGraphicsPDFRendererContext
    private let businessName: String
    private let number: String
    private let version: Int
    private let isDraft: Bool
    private var page = 0
    private var y: CGFloat = 64
    private let left: CGFloat = 42
    private let width: CGFloat = 528
    private let bottom: CGFloat = 738

    init(context: UIGraphicsPDFRendererContext, businessName: String, number: String, version: Int, isDraft: Bool) {
        self.context = context
        self.businessName = businessName
        self.number = number
        self.version = version
        self.isDraft = isDraft
    }

    func newPage() {
        context.beginPage()
        page += 1
        y = 64
        let graphics = context.cgContext
        graphics.setFillColor(UIColor.white.cgColor)
        graphics.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
        let header = businessName.isEmpty ? "DetailHandoff" : businessName
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (header as NSString).draw(in: CGRect(x: left, y: 25, width: width - 150, height: 20), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.darkGray, .paragraphStyle: paragraph])
        let marker = isDraft ? "DRAFT - NOT SEALED" : "CONDITION RECORD"
        (marker as NSString).draw(in: CGRect(x: 412, y: 25, width: 158, height: 20), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
        graphics.setStrokeColor(UIColor.lightGray.cgColor)
        graphics.setLineWidth(0.5)
        graphics.move(to: CGPoint(x: left, y: 49))
        graphics.addLine(to: CGPoint(x: left + width, y: 49))
        graphics.strokePath()
        ("\(number) / v\(version)" as NSString).draw(at: CGPoint(x: left, y: 757), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
        ("Page \(page)" as NSString).draw(at: CGPoint(x: 515, y: 757), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
    }

    func ensureSpace(_ height: CGFloat) {
        if y + height > bottom && y > 64 { newPage() }
    }

    /// TextKit measures actual glyph lines; each line is moved whole to a safe page area.
    /// This handles arbitrary-length notes, unbroken identifiers, Unicode and wrapped headings.
    func text(_ value: String, style: TextStyle = .body) {
        guard !value.isEmpty else { return }
        let font: UIFont
        switch style {
        case .title: font = .boldSystemFont(ofSize: 22)
        case .heading: font = .boldSystemFont(ofSize: 13)
        case .body: font = .systemFont(ofSize: 11)
        case .caption: font = .systemFont(ofSize: 9)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.lineBreakMode = .byWordWrapping
        let storage = NSTextStorage(string: value, attributes: [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: paragraph])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        let range = layout.glyphRange(for: container)
        if style == .title || style == .heading { ensureSpace(font.lineHeight * 2 + 18) }
        layout.enumerateLineFragments(forGlyphRange: range) { rect, _, _, glyphRange, _ in
            self.ensureSpace(rect.height)
            let origin = CGPoint(x: self.left, y: self.y - rect.minY)
            layout.drawBackground(forGlyphRange: glyphRange, at: origin)
            layout.drawGlyphs(forGlyphRange: glyphRange, at: origin)
            self.y += rect.height
        }
        y += style == .title ? 12 : 8
    }

    func image(_ image: UIImage, maximumHeight: CGFloat) {
        let scale = min(width / image.size.width, maximumHeight / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        ensureSpace(size.height + 12)
        image.draw(in: CGRect(x: left + (width - size.width) / 2, y: y, width: size.width, height: size.height))
        y += size.height + 12
    }

    func signature(_ strokes: [SignatureStroke]) {
        ensureSpace(140)
        let rect = CGRect(x: left, y: y, width: width, height: 120)
        let graphics = context.cgContext
        graphics.saveGState()
        graphics.setStrokeColor(UIColor.lightGray.cgColor)
        graphics.setLineWidth(0.5)
        graphics.stroke(rect)
        graphics.clip(to: rect.insetBy(dx: 1, dy: 1))
        graphics.setStrokeColor(UIColor.black.cgColor)
        graphics.setLineWidth(2)
        graphics.setLineCap(.round)
        graphics.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            graphics.move(to: CGPoint(x: rect.minX + CGFloat(first.x) * rect.width, y: rect.minY + CGFloat(first.y) * rect.height))
            for point in stroke.points.dropFirst() {
                graphics.addLine(to: CGPoint(x: rect.minX + CGFloat(point.x) * rect.width, y: rect.minY + CGFloat(point.y) * rect.height))
            }
            graphics.strokePath()
        }
        graphics.restoreGState()
        y += 140
    }
}
