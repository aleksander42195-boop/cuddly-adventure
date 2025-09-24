import SwiftUI

struct StudiesView: View {
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
                ForEach(grouped, id: \.0) { section in
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text(section.0.rawValue).font(.headline)
                            ForEach(section.1) { s in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.title).font(.subheadline).bold()
                                    Text("\(s.authors) • \(s.journal) (\(s.year))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let url = s.url {
                                        Link("View source", destination: url)
                                            .font(.caption)
                                    }
                                    if !s.takeaways.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(s.takeaways, id: \.self) { t in
                                                HStack(alignment: .top, spacing: 6) {
                                                    Text("•").bold()
                                                    Text(t).fixedSize(horizontal: false, vertical: true)
                                                }
                                                .font(.caption)
                                            }
                                        }
                                    }
                                }
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

#Preview { StudiesView() }
