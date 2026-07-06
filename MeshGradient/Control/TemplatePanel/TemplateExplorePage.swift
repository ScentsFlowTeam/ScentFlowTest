import SwiftUI

struct TemplateExplorePage: View {
    @EnvironmentObject private var app: AppModel

    @State private var selectedCollection: TemplateCollection = .all
    @State private var searchText = ""
    @State private var downloadingTemplateIDs: Set<UUID> = []

    private let columns = [
        GridItem(.adaptive(minimum: 156), spacing: 14)
    ]

    private var visibleTemplates: [TemplateCatalogItem] {
        TemplateCatalogItem.catalog.filter { item in
            let matchesCollection = selectedCollection == .all || item.collection == selectedCollection
            let matchesSearch = searchText.isEmpty
                || item.template.name.localizedCaseInsensitiveContains(searchText)
                || item.author.localizedCaseInsensitiveContains(searchText)
                || item.template.scentPodNames.joined(separator: " ").localizedCaseInsensitiveContains(searchText)

            return matchesCollection && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                collectionPicker
                templateGrid
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Template Explore")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search templates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Backend upload support will replace this placeholder action.
                } label: {
                    Image(systemName: "icloud.and.arrow.up")
                }
                .disabled(true)
                .accessibilityLabel("Upload template")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
//            Text("Discover templates")
//                .font(.largeTitle.weight(.semibold))
//                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                metricView(value: "24", label: "Templates")
                metricView(value: "8.7K", label: "Downloads")
                metricView(value: "12", label: "Authors")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var collectionPicker: some View {
        Picker("Collection", selection: $selectedCollection) {
            ForEach(TemplateCollection.allCases) { collection in
                Text(collection.title).tag(collection)
            }
        }
        .pickerStyle(.segmented)
    }

    private var templateGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(visibleTemplates) { item in
                TemplateExploreCard(
                    item: item,
                    isDownloaded: isDownloaded(item.template),
                    isDownloading: downloadingTemplateIDs.contains(item.template.id),
                    onDownload: { download(item.template) }
                )
            }
        }
    }

    private func metricView(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func isDownloaded(_ template: ScentsTemplate) -> Bool {
        app.templatesService.templates.contains { local in
            local.id == template.id
        }
    }

    private func download(_ template: ScentsTemplate) {
        guard !isDownloaded(template), !downloadingTemplateIDs.contains(template.id) else { return }

        downloadingTemplateIDs.insert(template.id)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            app.templatesService.importDownloaded(template)
            downloadingTemplateIDs.remove(template.id)
        }
    }
}

private struct TemplateExploreCard: View {
    let item: TemplateCatalogItem
    let isDownloaded: Bool
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                GradientContainerCircle(
                    colors: item.previewColors,
                    animate: false,
                    isTemplate: true
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 18)

                Button(action: onDownload) {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: isDownloaded ? "checkmark" : "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                }
                .buttonStyle(.glass)
                .disabled(isDownloaded || isDownloading)
                .accessibilityLabel(downloadButtonAccessibilityLabel)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.template.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("by \(item.author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(item.template.scentPodNames.prefix(4).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .topLeading)
            }

            HStack(spacing: 10) {
                Label(item.downloadsText, systemImage: "arrow.down.circle")
                Label(item.ratingText, systemImage: "star.fill")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var downloadButtonAccessibilityLabel: String {
        if isDownloading {
            return "Downloading template"
        }

        return isDownloaded ? "Downloaded" : "Download template"
    }
}

private enum TemplateCollection: String, CaseIterable, Identifiable {
    case all
    case featured
    case relaxing
    case energizing
    case seasonal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured: return "Featured"
        case .relaxing: return "Relax"
        case .energizing: return "Energy"
        case .seasonal: return "Season"
        case .all: return "All"
        }
    }
}

private struct TemplateCatalogItem: Identifiable {
    let id: UUID
    let template: ScentsTemplate
    let author: String
    let collection: TemplateCollection
    let downloads: Int
    let rating: Double
    let previewColors: [Color]

    var downloadsText: String {
        if downloads >= 1000 {
            return String(format: "%.1fK", Double(downloads) / 1000)
        }

        return "\(downloads)"
    }

    var ratingText: String {
        String(format: "%.1f", rating)
    }

    init(
        id: UUID,
        name: String,
        scents: [String],
        author: String,
        collection: TemplateCollection,
        downloads: Int,
        rating: Double,
        previewColors: [Color]
    ) {
        self.id = id
        self.template = ScentsTemplate(id: id, name: name, scentPodNames: scents)
        self.author = author
        self.collection = collection
        self.downloads = downloads
        self.rating = rating
        self.previewColors = previewColors
    }

    static let catalog: [TemplateCatalogItem] = [
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58001") ?? UUID(),
            name: "Morning Citrus",
            scents: ["Orange", "Lemon", "Mint"],
            author: "ScentFlow Lab",
            collection: .featured,
            downloads: 1840,
            rating: 4.8,
            previewColors: [.orange.opacity(0.72), .yellow.opacity(0.68), .green.opacity(0.55)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58002") ?? UUID(),
            name: "Ocean Desk",
            scents: ["Ocean", "Mint", "Bluebell"],
            author: "Aroma Studio",
            collection: .featured,
            downloads: 1260,
            rating: 4.7,
            previewColors: [.cyan.opacity(0.65), .green.opacity(0.45), .blue.opacity(0.62)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58003") ?? UUID(),
            name: "Quiet Reading",
            scents: ["Sandalwood", "Bluebell", "Ocean"],
            author: "Mia Chen",
            collection: .relaxing,
            downloads: 980,
            rating: 4.6,
            previewColors: [.purple.opacity(0.62), .blue.opacity(0.50), .cyan.opacity(0.42)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58004") ?? UUID(),
            name: "Focus Sprint",
            scents: ["Mint", "Lemon", "Pepper"],
            author: "North Lab",
            collection: .energizing,
            downloads: 2140,
            rating: 4.9,
            previewColors: [.green.opacity(0.62), .yellow.opacity(0.66), .red.opacity(0.48)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58005") ?? UUID(),
            name: "Winter Lobby",
            scents: ["Sandalwood", "Orange", "Pepper"],
            author: "ScentFlow Lab",
            collection: .seasonal,
            downloads: 760,
            rating: 4.5,
            previewColors: [.purple.opacity(0.58), .orange.opacity(0.62), .red.opacity(0.42)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58006") ?? UUID(),
            name: "Clean Linen Air",
            scents: ["Ocean", "Bluebell", "Lemon"],
            author: "Ivy Park",
            collection: .relaxing,
            downloads: 1340,
            rating: 4.7,
            previewColors: [.cyan.opacity(0.48), .blue.opacity(0.52), .yellow.opacity(0.38)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58007") ?? UUID(),
            name: "Tea House Calm",
            scents: ["Mint", "Sandalwood", "Lemon"],
            author: "Jun Atelier",
            collection: .relaxing,
            downloads: 1680,
            rating: 4.8,
            previewColors: [.green.opacity(0.50), .purple.opacity(0.48), .yellow.opacity(0.40)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58008") ?? UUID(),
            name: "Hotel Arrival",
            scents: ["Orange", "Bluebell", "Sandalwood"],
            author: "ScentFlow Lab",
            collection: .featured,
            downloads: 2450,
            rating: 4.9,
            previewColors: [.orange.opacity(0.58), .blue.opacity(0.48), .purple.opacity(0.52)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58009") ?? UUID(),
            name: "Kitchen Reset",
            scents: ["Lemon", "Mint", "Ocean"],
            author: "Aroma Studio",
            collection: .energizing,
            downloads: 920,
            rating: 4.5,
            previewColors: [.yellow.opacity(0.68), .green.opacity(0.54), .cyan.opacity(0.46)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58010") ?? UUID(),
            name: "Deep Work",
            scents: ["Pepper", "Ocean", "Mint"],
            author: "North Lab",
            collection: .energizing,
            downloads: 3110,
            rating: 4.8,
            previewColors: [.red.opacity(0.46), .cyan.opacity(0.56), .green.opacity(0.48)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58011") ?? UUID(),
            name: "Rainy Window",
            scents: ["Ocean", "Sandalwood", "Bluebell"],
            author: "Mia Chen",
            collection: .relaxing,
            downloads: 1110,
            rating: 4.6,
            previewColors: [.cyan.opacity(0.46), .purple.opacity(0.46), .blue.opacity(0.56)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58012") ?? UUID(),
            name: "Summer Market",
            scents: ["Orange", "Pepper", "Lemon"],
            author: "Ivy Park",
            collection: .seasonal,
            downloads: 1470,
            rating: 4.7,
            previewColors: [.orange.opacity(0.68), .red.opacity(0.48), .yellow.opacity(0.60)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58013") ?? UUID(),
            name: "Spa Steam",
            scents: ["Mint", "Ocean", "Sandalwood"],
            author: "Aroma Studio",
            collection: .featured,
            downloads: 2870,
            rating: 4.9,
            previewColors: [.green.opacity(0.48), .cyan.opacity(0.58), .purple.opacity(0.42)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58014") ?? UUID(),
            name: "After Dinner",
            scents: ["Sandalwood", "Orange", "Bluebell"],
            author: "Jun Atelier",
            collection: .relaxing,
            downloads: 650,
            rating: 4.4,
            previewColors: [.purple.opacity(0.56), .orange.opacity(0.46), .blue.opacity(0.44)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58015") ?? UUID(),
            name: "Workout Start",
            scents: ["Pepper", "Mint", "Lemon"],
            author: "North Lab",
            collection: .energizing,
            downloads: 1980,
            rating: 4.6,
            previewColors: [.red.opacity(0.58), .green.opacity(0.58), .yellow.opacity(0.52)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58016") ?? UUID(),
            name: "Autumn Hallway",
            scents: ["Sandalwood", "Pepper", "Orange"],
            author: "ScentFlow Lab",
            collection: .seasonal,
            downloads: 1230,
            rating: 4.7,
            previewColors: [.purple.opacity(0.50), .red.opacity(0.42), .orange.opacity(0.62)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58017") ?? UUID(),
            name: "Blue Hour",
            scents: ["Bluebell", "Ocean", "Mint"],
            author: "Mia Chen",
            collection: .featured,
            downloads: 1720,
            rating: 4.8,
            previewColors: [.blue.opacity(0.66), .cyan.opacity(0.50), .green.opacity(0.38)]
        ),
        TemplateCatalogItem(
            id: UUID(uuidString: "90FE367D-3D7C-4DC2-A429-C643A0A58018") ?? UUID(),
            name: "Spring Porch",
            scents: ["Bluebell", "Lemon", "Orange"],
            author: "Ivy Park",
            collection: .seasonal,
            downloads: 890,
            rating: 4.5,
            previewColors: [.blue.opacity(0.54), .yellow.opacity(0.56), .orange.opacity(0.46)]
        )
    ]
}

#Preview {
    NavigationStack {
        TemplateExplorePage()
    }
    .environmentObject(AppModel())
    .preferredColorScheme(.dark)
}
