import SwiftUI

struct StudiesView: View {
    @State private var savedSlugs: Set<String> = Set(BookmarkStore.shared.allSlugs())
    private var grouped: [(Study.Category, [Study])] {
        Dictionary(grouping: HRVStudies.all, by: { $0.category })
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("HRV studies for training, diet, breathing, wellbeing")
                            .font(.title2).bold()
                        Text("Curated, publicly available sources with practical takeaways.")
                            .foregroundStyle(.secondary)
                    }
                }
                if !BookmarkStore.shared.allStudies().isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Saved").font(.headline)
                            ForEach(BookmarkStore.shared.allStudies()) { s in
                                StudyRow(study: s, savedSlugs: $savedSlugs)
                                Divider().opacity(0.2)
                            }
                        }
                    }
                }
                ForEach(grouped, id: \.0) { section in
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text(section.0.rawValue).font(.headline)
                            ForEach(section.1) { s in
                                StudyRow(study: s, savedSlugs: $savedSlugs)
                                    .padding(.vertical, 4)
                                Divider().opacity(0.2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("HRV Studies")
        .accessibilityLabel("HRV studies grouped by category with practical takeaways")
    }
}

private struct StudyRow: View {
    let study: Study
    @Binding var savedSlugs: Set<String>

    var isSaved: Bool { savedSlugs.contains(study.slug) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(study.title).font(.subheadline).bold()
                Spacer()
                Button {
                    BookmarkStore.shared.toggle(slug: study.slug)
                    savedSlugs = Set(BookmarkStore.shared.allSlugs())
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isSaved ? .yellow : .secondary)
                        .accessibilityLabel(isSaved ? "Remove bookmark" : "Save")
                }
                .buttonStyle(.plain)
            }
            Text("\(study.authors) • \(study.journal) (\(study.year))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = study.url {
                Link("View source", destination: url)
                    .font(.caption)
            }
            if !study.takeaways.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(study.takeaways, id: \.self) { t in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").bold()
                            Text(t).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

#Preview { StudiesView() }
