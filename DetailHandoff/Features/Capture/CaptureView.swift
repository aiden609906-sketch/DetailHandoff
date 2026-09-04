import PhotosUI
import SwiftData
import SwiftUI
import UIKit

protocol CaptureStorageCapacityChecking {
    func availableImportantCapacity() throws -> Int64
}

struct FileSystemCaptureStorageCapacityChecker: CaptureStorageCapacityChecking {
    func availableImportantCapacity() throws -> Int64 {
        let values = try MediaStore.defaultRoot.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
            throw CocoaError(.fileReadUnknown)
        }
        return Int64(capacity)
    }
}

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext

    let job: JobRecord
    let phase: CapturePhase
    private let capacityChecker: any CaptureStorageCapacityChecking

    @State private var document = CaptureDocument.empty
    @State private var selectedImports: [PhotosPickerItem] = []
    @State private var activeSlotID: String?
    @State private var isPhotosPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isImporting = false
    @State private var referenceOpacity = 0.45
    @State private var skipSlot: CaptureSlot?
    @State private var skipReason = ""
    @State private var errorMessage: String?
    @State private var storageDecision: CaptureStorageDecision?
    @State private var pendingAction: PendingAction?
    @State private var selectedPhoto: CapturedPhoto?

    init(job: JobRecord, phase: CapturePhase) {
        self.init(job: job, phase: phase, capacityChecker: FileSystemCaptureStorageCapacityChecker())
    }

    init(job: JobRecord, phase: CapturePhase, capacityChecker: any CaptureStorageCapacityChecking) {
        self.job = job
        self.phase = phase
        self.capacityChecker = capacityChecker
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                header
                if phase == .after { beforeReference }
                ForEach(document.slots) { slot in
                    slotCard(slot)
                }
            }
            .padding(AppTheme.spacing16)
        }
        .navigationTitle(phase == .before ? "Before photos" : "After photos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadDocument)
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $selectedImports,
            maxSelectionCount: 20,
            matching: .images
        )
        .task(id: selectedImports) {
            let items = selectedImports
            guard !items.isEmpty else { return }
            await importPhotos(items)
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            ZStack {
                CameraPicker(
                    isPresented: $isCameraPresented,
                    referenceOpacity: $referenceOpacity,
                    referenceImageData: cameraReferenceData,
                    onResult: handleCameraResult
                )
                .ignoresSafeArea()

                if phase == .after, cameraReferenceData != nil {
                    referenceOpacityControl
                }
            }
        }
        .alert("Skip this view", isPresented: Binding(get: { skipSlot != nil }, set: { if !$0 { skipSlot = nil } })) {
            TextField("Reason", text: $skipReason)
            Button("Save") { saveSkip() }
            Button("Cancel", role: .cancel) { skipSlot = nil }
        } message: {
            Text("Add a reason so the missing \(phase.rawValue) photo is clear in review.")
        }
        .alert("Storage check", isPresented: Binding(get: { storageDecision != nil }, set: { if !$0 { storageDecision = nil } })) {
            storageButtons
        } message: {
            Text(storageMessage)
        }
        .alert("Capture issue", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            if errorMessage?.contains("Settings") == true {
                Button("Open Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .sheet(item: $selectedPhoto) { photo in
            FullPhotoView(photo: photo)
        }
    }

    private var header: some View {
        let count = document.photos.filter { $0.phase == phase }.count
        return VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(phase == .before ? "Document starting condition" : "Match the Before views")
                .font(.title3.weight(.semibold))
            Text("\(count) photos across \(document.slots.count) views. Add as many photos to a view as needed.")
                .foregroundStyle(.secondary)
        }
        .reportCard()
    }

    @ViewBuilder
    private var beforeReference: some View {
        let before = document.photos.filter { $0.phase == .before }
        if !before.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                Text("Before reference")
                    .font(.headline)
                Text("Use this resizable reference while matching the finished vehicle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: AppTheme.spacing8) {
                        ForEach(before) { photo in
                            ThumbnailImage(photo: photo)
                                .frame(width: 220, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture { selectedPhoto = photo }
                        }
                    }
                }
            }
            .reportCard()
        }
    }

    private func slotCard(_ slot: CaptureSlot) -> some View {
        let photos = document.photos.filter { $0.slotID == slot.id && $0.phase == phase }
        let skip = document.skips.first { $0.slotID == slot.id && $0.phase == phase }
        return VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.name).font(.headline)
                    Text(slot.isRequired ? "Required view" : "Optional view")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
            }
            if let skip {
                HStack {
                    Label("Skipped: \(skip.reason)", systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                    Spacer()
                    Button("Clear") { clearSkip(for: slot) }
                        .disabled(isImporting || !isMutable)
                }
                .foregroundStyle(.secondary)
            }
            if !photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: AppTheme.spacing8) {
                        ForEach(photos) { photo in
                            VStack(alignment: .trailing, spacing: 4) {
                                ThumbnailImage(photo: photo)
                                    .frame(width: 112, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .onTapGesture { selectedPhoto = photo }
                                Button("Remove", role: .destructive) { remove(photo) }
                                    .font(.caption)
                                    .disabled(isImporting || !isMutable)
                            }
                        }
                    }
                }
            }
            HStack {
                Button(photos.isEmpty ? "Take photo" : "Retake") { begin(.camera(slot.id)) }
                Button("Import") { begin(.importPhotos(slot.id)) }
                Spacer()
                Button(skip == nil ? "Skip" : "Change skip") {
                    skipReason = skip?.reason ?? ""
                    skipSlot = slot
                }
            }
            .buttonStyle(.bordered)
            .disabled(isImporting || !isMutable)
        }
        .reportCard()
    }

    private var referenceOpacityControl: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reference opacity")
                        .font(.caption.weight(.semibold))
                    Slider(value: $referenceOpacity, in: 0...0.8)
                }
                .padding(10)
                .frame(width: 170)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.trailing, AppTheme.spacing16)
            .padding(.bottom, 170)
        }
    }

    @ViewBuilder
    private var storageButtons: some View {
        switch storageDecision {
        case .warning:
            Button("Continue") { launchPendingAction() }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        case .unavailable:
            Button("Retry") { checkStorageAgain() }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        case .ready, .none:
            Button("OK", role: .cancel) {}
        }
    }

    private var storageMessage: String {
        switch storageDecision {
        case .warning(let availableBytes):
            "Only \(ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)) is available for important usage. You may continue, but saving can still fail."
        case .unavailable:
            "Available storage could not be checked. Capture and import are paused until you retry or cancel."
        case .ready, .none:
            ""
        }
    }

    private var isMutable: Bool { job.status != .finalized && job.status != .archived }

    private var cameraReferenceData: Data? {
        guard phase == .after,
              let slotID = activeSlotID,
              let photo = document.photos.first(where: { $0.slotID == slotID && $0.phase == .before }),
              let url = try? MediaStore(root: MediaStore.defaultRoot).url(for: photo.imagePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func begin(_ action: PendingAction) {
        pendingAction = action
        checkStorageAgain()
    }

    private func checkStorageAgain() {
        do {
            let decision = CapturePresentationState.storageDecision(availableBytes: try capacityChecker.availableImportantCapacity())
            storageDecision = decision == .ready ? nil : decision
            if decision == .ready { launchPendingAction() }
        } catch {
            storageDecision = .unavailable
        }
    }

    private func launchPendingAction() {
        storageDecision = nil
        guard let action = pendingAction else { return }
        activeSlotID = action.slotID
        pendingAction = nil
        switch action {
        case .camera: isCameraPresented = true
        case .importPhotos: isPhotosPickerPresented = true
        }
    }

    private func handleCameraResult(_ result: Result<Data, CameraPickerError>) {
        switch result {
        case .success(let data): addPhoto(data, slotID: activeSlotID)
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard let slotID = activeSlotID else { return }
        isImporting = true
        defer {
            isImporting = false
            selectedImports = []
            activeSlotID = nil
        }
        for item in items {
            do {
                try await EvidenceImport.loadAndSave(load: { try await item.loadTransferable(type: Data.self) }, save: { data in
                    try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot))
                        .addPhoto(to: job, data: data, slotID: slotID, phase: phase)
                })
                reloadDocument()
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                errorMessage = "This photo could not be saved. No workflow step was advanced. \(error.localizedDescription)"
                break
            }
        }
    }

    private func addPhoto(_ data: Data, slotID: String?) {
        guard let slotID else { return }
        do {
            try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot))
                .addPhoto(to: job, data: data, slotID: slotID, phase: phase)
            reloadDocument()
        } catch {
            errorMessage = "This photo could not be saved. No workflow step was advanced. \(error.localizedDescription)"
        }
        activeSlotID = nil
    }

    private func remove(_ photo: CapturedPhoto) {
        do {
            try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).removePhoto(from: job, photoID: photo.id)
            reloadDocument()
        } catch {
            errorMessage = "The photo could not be removed. \(error.localizedDescription)"
        }
    }

    private func saveSkip() {
        guard let slot = skipSlot else { return }
        do {
            try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot))
                .setSkip(on: job, slotID: slot.id, phase: phase, reason: skipReason)
            reloadDocument()
            skipSlot = nil
        } catch {
            errorMessage = "The skip reason could not be saved. \(error.localizedDescription)"
        }
    }

    private func clearSkip(for slot: CaptureSlot) {
        do {
            try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).clearSkip(on: job, slotID: slot.id, phase: phase)
            reloadDocument()
        } catch {
            errorMessage = "The skip reason could not be cleared. \(error.localizedDescription)"
        }
    }

    private func reloadDocument() {
        do {
            document = try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).document(for: job)
        } catch {
            errorMessage = "Capture records could not be read. \(error.localizedDescription)"
        }
    }
}

private enum PendingAction: Equatable {
    case camera(String)
    case importPhotos(String)

    var slotID: String {
        switch self {
        case .camera(let slotID), .importPhotos(let slotID): slotID
        }
    }
}

struct ThumbnailImage: View {
    let photo: CapturedPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Color.secondary.opacity(0.15).overlay { ProgressView() } }
        }
        .clipped()
        .task(id: photo.id) {
            let url = try? MediaStore(root: MediaStore.defaultRoot).url(for: photo.thumbnailPath)
            image = url.flatMap { UIImage(contentsOfFile: $0.path) }
        }
        .accessibilityLabel("Captured photo")
    }
}

struct FullImagePreview: View {
    let photo: CapturedPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Color.secondary.opacity(0.15).overlay { ProgressView() } }
        }
        .task(id: photo.id) {
            let url = try? MediaStore(root: MediaStore.defaultRoot).url(for: photo.imagePath)
            image = url.flatMap { UIImage(contentsOfFile: $0.path) }
        }
    }
}

struct FullPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: CapturedPhoto

    var body: some View {
        NavigationStack {
            FullImagePreview(photo: photo)
                .padding()
                .navigationTitle("Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
