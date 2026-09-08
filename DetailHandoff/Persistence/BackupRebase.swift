import Foundation

/// A storage migration, never a new customer acknowledgment. Call only after original validation.
@MainActor
enum BackupRebase {
    static func apply(to original: BackupManifest, paths: [String: String], graph: BackupGraph) throws -> BackupManifest {
        var result = original
        result.profile.logoImagePath = try mapped(original.profile.logoImagePath, paths: paths)
        for index in result.jobs.indices {
            var job = result.jobs[index]
            if let data = job.captureData {
                let capture = try JSONDecoder().decode(CaptureDocument.self, from: data)
                job.captureData = try JSONEncoder().encode(remap(capture, paths: paths))
            }
            if let data = job.acknowledgmentData {
                var acknowledgment = try JSONDecoder().decode(AcknowledgmentRecord.self, from: data)
                let capture = try job.captureData.map { try JSONDecoder().decode(CaptureDocument.self, from: $0) } ?? .empty
                let newDigest = try AcknowledgmentContentDigest.make(for: job.makeModel(), document: capture)
                if graph.currentAcknowledgments.contains(job.id) {
                    acknowledgment.contentDigest = newDigest
                    job.acknowledgmentData = try JSONEncoder().encode(acknowledgment)
                } else {
                    // Keep stale bytes intact. Even an accidental digest collision must fail closed.
                    guard acknowledgment.contentDigest != newDigest else { throw BackupError.invalidPackage("stale acknowledgment became current during migration") }
                }
            }
            if let data = job.reportsData {
                var reports = try JSONDecoder().decode([ReportVersion].self, from: data)
                for reportIndex in reports.indices {
                    reports[reportIndex].pdfPath = try required(reports[reportIndex].pdfPath, paths: paths)
                    var snapshot = reports[reportIndex].snapshot
                    snapshot.logoImagePath = try mapped(snapshot.logoImagePath, paths: paths)
                    snapshot.capture = try remap(snapshot.capture, paths: paths)
                    // Every original frozen snapshot was verified against its recorded digest scope.
                    snapshot.acknowledgment.contentDigest = try AcknowledgmentContentDigest.makeForFrozenRecord(snapshot.acknowledgment, job: BackupGraph.snapshotJob(snapshot), document: snapshot.capture)
                    reports[reportIndex].snapshot = snapshot
                }
                job.reportsData = try JSONEncoder().encode(reports)
            }
            result.jobs[index] = job
        }
        result.assets = try original.assets.map { asset in
            var mappedAsset = asset
            mappedAsset.relativePath = try required(asset.relativePath, paths: paths)
            return mappedAsset
        }
        return result
    }

    private static func remap(_ capture: CaptureDocument, paths: [String: String]) throws -> CaptureDocument {
        var capture = capture
        for index in capture.photos.indices {
            capture.photos[index].imagePath = try required(capture.photos[index].imagePath, paths: paths)
            capture.photos[index].thumbnailPath = try required(capture.photos[index].thumbnailPath, paths: paths)
        }
        return capture
    }

    private static func mapped(_ path: String?, paths: [String: String]) throws -> String? {
        try path.map { try required($0, paths: paths) }
    }

    private static func required(_ path: String, paths: [String: String]) throws -> String {
        guard let result = paths[path] else { throw BackupError.invalidPackage("missing path mapping") }
        return result
    }
}
