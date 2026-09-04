import XCTest
@testable import DetailHandoff

final class ReportSnapshotContactTests: XCTestCase {
    @MainActor
    func testSnapshotCopiesCustomerContactAndServiceLocation() {
        let job = JobRecord(customerName: "Avery", vehicleLabel: "Roadster", plate: "EV1", color: "Blue", serviceName: "Wash", notes: "")
        job.customerPhone = "555-0123"
        job.customerEmail = "avery@example.com"
        job.location = "100 Main St"
        let business = BusinessProfile(businessName: "Northstar")
        let acknowledgment = AcknowledgmentRecord(method: .customerUnavailable, customerName: "Avery", recordedAt: .now, confirmationText: AcknowledgmentRecord.confirmationText, unavailableReason: "Away", strokes: [], contentDigest: "digest")

        let snapshot = ReportSnapshot(job: job, business: business, capture: .empty, acknowledgment: acknowledgment)

        XCTAssertEqual(snapshot.customerPhone, "555-0123")
        XCTAssertEqual(snapshot.customerEmail, "avery@example.com")
        XCTAssertEqual(snapshot.serviceLocation, "100 Main St")
    }
}
