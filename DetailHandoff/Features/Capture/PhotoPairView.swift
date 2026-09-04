import SwiftData
import SwiftUI

struct PhotoPairView: View {
    @Environment(\.modelContext) private var modelContext

    let job: JobRecord
    @State private var document = CaptureDocument.empty
    @State private var errorMessage: String?
    @State private var selectedPhoto: CapturedPhoto?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.spacing16) {
                Text("Before and After")
                    .font(.title3.weight(.semibold))
                Text("Photos are grouped only by their saved template view.")
                    .foregroundStyle(.secondary)
                ForEach(CapturePresentationState.pairs(in: document)) { pair in
                    pairCard(pair)
                }
            }
            .padding(AppTheme.spacing16)
        }
        .navigationTitle("Photo pairs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadDocument)
        .alert("Unable to open photo pairs", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .sheet(item: $selectedPhoto) { photo in FullPhotoView(photo: photo) }
    }

    private func pairCard(_ pair: CaptureSlotPair) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(pair.slot.name).font(.headline)
            HStack(alignment: .top, spacing: AppTheme.spacing12) {
                phaseColumn("Before", photos: pair.beforePhotos, skip: pair.beforeSkip)
                Divider()
                phaseColumn("After", photos: pair.afterPhotos, skip: pair.afterSkip)
            }
        }
        .reportCard()
    }

    private func phaseColumn(_ title: String, photos: [CapturedPhoto], skip: CaptureSkip?) -> some View {
        let presentation = CapturePresentationState.phasePresentation(photos: photos, skip: skip)
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(title).font(.subheadline.weight(.semibold))
            if !presentation.photos.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: AppTheme.spacing8)], spacing: AppTheme.spacing8) {
                    ForEach(presentation.photos) { photo in
                        ThumbnailImage(photo: photo)
                            .frame(height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture { selectedPhoto = photo }
                    }
                }
            }
            if let skipReason = presentation.skipReason {
                Label(skipReason, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if presentation.showsEmptyState {
                Text("No photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reloadDocument() {
        do {
            document = try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).document(for: job)
        } catch {
            errorMessage = "The saved capture record could not be read. \(error.localizedDescription)"
        }
    }
}
