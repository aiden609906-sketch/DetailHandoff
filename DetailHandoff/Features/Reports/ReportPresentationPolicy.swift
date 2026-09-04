import Foundation

/// Keeps immutable report actions separate from the workflow engine that owns status changes.
enum ReportPresentationPolicy {
    static func canPreviewDraft(for status: JobStatus) -> Bool {
        status == .review
    }

    static func canSeal(for status: JobStatus) -> Bool {
        status == .review
    }

    static func canCreateRevision(for status: JobStatus) -> Bool {
        status == .finalized
    }

    static func canOpenStoredVersion(for status: JobStatus) -> Bool {
        status == .finalized || status == .archived
    }

    static func canShareStoredVersion(for status: JobStatus) -> Bool {
        canOpenStoredVersion(for: status)
    }
}
