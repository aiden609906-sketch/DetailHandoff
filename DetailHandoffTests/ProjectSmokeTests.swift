import XCTest
@testable import DetailHandoff

final class ProjectSmokeTests: XCTestCase {
    func testProductIdentity() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            "DetailHandoff"
        )
    }
}
