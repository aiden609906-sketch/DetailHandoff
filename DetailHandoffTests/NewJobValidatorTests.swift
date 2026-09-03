import XCTest
@testable import DetailHandoff

final class NewJobValidatorTests: XCTestCase {
    func testValidateRejectsMissingVehicle() {
        XCTAssertEqual(
            NewJobValidator.validate(vehicleLabel: "", serviceName: "Full detail"),
            .missingVehicle
        )
    }

    func testValidateRejectsWhitespaceOnlyVehicle() {
        XCTAssertEqual(
            NewJobValidator.validate(vehicleLabel: " \n ", serviceName: "Full detail"),
            .missingVehicle
        )
    }

    func testValidateRejectsMissingService() {
        XCTAssertEqual(
            NewJobValidator.validate(vehicleLabel: "2021 Honda Accord", serviceName: ""),
            .missingService
        )
    }

    func testValidateRejectsWhitespaceOnlyService() {
        XCTAssertEqual(
            NewJobValidator.validate(vehicleLabel: "2021 Honda Accord", serviceName: "  \t"),
            .missingService
        )
    }

    func testValidateAcceptsVehicleAndService() {
        XCTAssertNil(
            NewJobValidator.validate(vehicleLabel: "2021 Honda Accord", serviceName: "Full detail")
        )
    }
}
