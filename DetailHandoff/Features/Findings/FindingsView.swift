import SwiftData
import SwiftUI

struct FindingsView: View {
    @Environment(\.modelContext) private var modelContext

    let job: JobRecord
    @State private var document = CaptureDocument.empty
    @State private var editingFinding: VehicleFinding?
    @State private var findingToDelete: VehicleFinding?
    @State private var errorMessage: String?

    private var isMutable: Bool { job.status != .finalized && job.status != .archived }

    var body: some View {
        List {
            if document.findings.isEmpty {
                ContentUnavailableView(
                    "No findings recorded",
                    systemImage: "magnifyingglass",
                    description: Text("Record visible condition tied to its photo evidence.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(document.findings) { finding in
                    findingRow(finding)
                }
            }
        }
        .navigationTitle("Condition findings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isMutable {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add finding", systemImage: "plus") { beginAdding() }
                }
            }
        }
        .onAppear(perform: reloadDocument)
        .sheet(item: $editingFinding) { finding in
            FindingEditor(
                document: document,
                finding: finding,
                isNew: !document.findings.contains(where: { $0.id == finding.id }),
                onSave: save,
                onCancel: { editingFinding = nil }
            )
        }
        .confirmationDialog(
            "Delete this finding?",
            isPresented: Binding(get: { findingToDelete != nil }, set: { if !$0 { findingToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete finding", role: .destructive) { deleteFinding() }
            Button("Cancel", role: .cancel) { findingToDelete = nil }
        } message: {
            Text("The finding will be removed from this job's capture record.")
        }
        .alert("Findings issue", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private func findingRow(_ finding: VehicleFinding) -> some View {
        let slotName = document.slots.first(where: { $0.id == finding.slotID })?.name ?? finding.slotID
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            HStack {
                Text(finding.kind).font(.headline)
                Spacer()
                Text(finding.severity).font(.subheadline.weight(.medium))
            }
            Text(slotName).foregroundStyle(.secondary)
            if !finding.notes.isEmpty { Text(finding.notes) }
            ScrollView(.horizontal) {
                HStack(spacing: AppTheme.spacing8) {
                    ForEach(photos(for: finding)) { photo in
                        ThumbnailImage(photo: photo)
                            .frame(width: 96, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            if isMutable {
                HStack {
                    Button("Edit") { editingFinding = finding }
                    Button("Delete", role: .destructive) { findingToDelete = finding }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func beginAdding() {
        guard let firstSlot = document.slots.first else { return }
        editingFinding = VehicleFinding(
            slotID: firstSlot.id,
            kind: FindingKind.scratch.rawValue,
            severity: FindingSeverity.minor.rawValue,
            notes: "",
            photoIDs: []
        )
    }

    private func save(_ finding: VehicleFinding) {
        do {
            try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot))
                .saveFinding(on: job, finding: finding)
            editingFinding = nil
            reloadDocument()
        } catch {
            errorMessage = "The finding could not be saved. \(error.localizedDescription)"
        }
    }

    private func deleteFinding() {
        guard let finding = findingToDelete else { return }
        do {
            try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot))
                .removeFinding(from: job, findingID: finding.id)
            findingToDelete = nil
            reloadDocument()
        } catch {
            errorMessage = "The finding could not be deleted. \(error.localizedDescription)"
        }
    }

    private func photos(for finding: VehicleFinding) -> [CapturedPhoto] {
        document.photos.filter { finding.photoIDs.contains($0.id) }
    }

    private func reloadDocument() {
        do {
            document = try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).document(for: job)
        } catch {
            errorMessage = "The saved findings could not be read. \(error.localizedDescription)"
        }
    }
}

private struct FindingEditor: View {
    let document: CaptureDocument
    let finding: VehicleFinding
    let isNew: Bool
    let onSave: (VehicleFinding) -> Void
    let onCancel: () -> Void

    @State private var slotID: String
    @State private var kind: FindingKind
    @State private var severity: FindingSeverity
    @State private var notes: String
    @State private var photoIDs: Set<UUID>

    init(
        document: CaptureDocument,
        finding: VehicleFinding,
        isNew: Bool,
        onSave: @escaping (VehicleFinding) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.document = document
        self.finding = finding
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _slotID = State(initialValue: finding.slotID)
        _kind = State(initialValue: FindingKind(rawValue: finding.kind) ?? .other)
        _severity = State(initialValue: FindingSeverity(rawValue: finding.severity) ?? .minor)
        _notes = State(initialValue: finding.notes)
        _photoIDs = State(initialValue: Set(finding.photoIDs))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("View", selection: $slotID) {
                    ForEach(document.slots) { slot in Text(slot.name).tag(slot.id) }
                }
                Picker("Kind", selection: $kind) {
                    ForEach(FindingKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }
                Picker("Severity", selection: $severity) {
                    ForEach(FindingSeverity.allCases) { severity in Text(severity.rawValue).tag(severity) }
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 96)
                }
                Section("Photo evidence") {
                    if selectedSlotPhotos.isEmpty {
                        Text("Add a photo to this view before recording a finding.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedSlotPhotos) { photo in
                            Toggle(isOn: photoSelection(for: photo.id)) {
                                ThumbnailImage(photo: photo)
                                    .frame(width: 80, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New finding" : "Edit finding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(VehicleFinding(
                            id: finding.id,
                            slotID: slotID,
                            kind: kind.rawValue,
                            severity: severity.rawValue,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            photoIDs: Array(photoIDs)
                        ))
                    }
                    .disabled(photoIDs.isEmpty)
                }
            }
        }
        .onChange(of: slotID) { _, _ in photoIDs = [] }
    }

    private var selectedSlotPhotos: [CapturedPhoto] {
        document.photos.filter { $0.slotID == slotID }
    }

    private func photoSelection(for photoID: UUID) -> Binding<Bool> {
        Binding(
            get: { photoIDs.contains(photoID) },
            set: { selected in
                if selected { photoIDs.insert(photoID) }
                else { photoIDs.remove(photoID) }
            }
        )
    }
}
