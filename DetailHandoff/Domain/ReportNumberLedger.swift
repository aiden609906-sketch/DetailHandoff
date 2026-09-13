import Foundation

enum ReportNumberLedgerError: Error, Equatable {
    case corruptLedger
}

/// Durable issuance high-water marks, independent of purgeable jobs and their evidence.
/// Backup/restore must preserve this payload and merge each day's maximum, never replace
/// a larger local reservation with a smaller imported one.
struct ReportNumberLedger: Codable, Equatable {
    static let currentSchemaVersion = 1
    private(set) var schemaVersion: Int = ReportNumberLedger.currentSchemaVersion
    private(set) var highWaterByDay: [String: Int] = [:]

    static func decode(_ data: Data?) throws -> ReportNumberLedger {
        guard let data else { return ReportNumberLedger() }
        let ledger: ReportNumberLedger
        do { ledger = try JSONDecoder().decode(ReportNumberLedger.self, from: data) }
        catch { throw ReportNumberLedgerError.corruptLedger }
        guard ledger.schemaVersion == currentSchemaVersion,
              ledger.highWaterByDay.allSatisfy({ validDay($0.key) && (1...9999).contains($0.value) }) else {
            throw ReportNumberLedgerError.corruptLedger
        }
        return ledger
    }

    mutating func observe(reportNumber: String) throws {
        let parts = reportNumber.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "DH", Self.validDay(String(parts[1])),
              parts[2].count == 4, parts[2].allSatisfy({ $0.isASCII && $0.isNumber }),
              let maximum = Int(parts[2]), (1...9999).contains(maximum) else {
            throw ReportNumberLedgerError.corruptLedger
        }
        let day = String(parts[1])
        highWaterByDay[day] = max(highWaterByDay[day] ?? 0, maximum)
    }

    private static func validDay(_ day: String) -> Bool {
        guard day.count == 8, day.allSatisfy({ $0.isASCII && $0.isNumber }),
              let year = Int(day.prefix(4)), year > 0,
              let month = Int(day.dropFirst(4).prefix(2)), (1...12).contains(month),
              let dayOfMonth = Int(day.suffix(2)), (1...31).contains(dayOfMonth) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: dayOfMonth)
        guard let date = calendar.date(from: components) else { return false }
        let normalized = calendar.dateComponents([.year, .month, .day], from: date)
        return normalized.year == year && normalized.month == month && normalized.day == dayOfMonth
    }
}
