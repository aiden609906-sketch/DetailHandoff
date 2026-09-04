import Foundation

struct ReportVersion: Codable, Equatable, Identifiable {
    var id: UUID
    var reportNumber: String
    var version: Int
    var sealedAt: Date
    var pdfPath: String
    var sha256: String
    var snapshot: ReportSnapshot
}
