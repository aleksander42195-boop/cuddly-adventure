import SwiftUI

struct AdvancedStudyCard: View {
    let study: Study?
    let isLoading: Bool
    let onRefresh: () -> Void
    let onBookmark: () -> Void
    let onOpen: () -> Void
    let isBookmarked: Bool
    
    @State private var showFullStudy = false
    @State private var currentTakeawayIndex = 0
    
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    private var categoryColor: Color {
        guard let study = study else { return .blue }
        
        switch study.category {
        case .training: return .orange
        case .breathing: return .cyan
        case .methodology: return .purple
        case .general: return .green
        }
    }
    
    private var categoryIcon: String {
        guard let study = study else { return "doc.text" }
        
        switch study.category {
        case .training: return "figure.strengthtraining.traditional"
        case .breathing: return "lungs.fill"
        case .methodology: return "chart.bar.doc.horizontal"
        case .general: return "heart.text.square"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if isLoading {
                loadingSection
            } else if let study = study {
                studyContentSection(study: study)
                actionButtonsSection(study: study)
            } else {
                errorSection
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.indigo.opacity(0.9),
                            categoryColor.opacity(0.6),
                            Color.black.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(categoryColor.opacity(0.4), lineWidth: 2)
                )
                .shadow(color: categoryColor.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onReceive(timer) { _ in
            rotateTakeaways()
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: categoryIcon)
                        .foregroundColor(categoryColor)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(categoryColor.opacity(0.2))
                                .overlay(
                                    Circle()
                                        .stroke(categoryColor.opacity(0.5), lineWidth: 1)
                                )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Research Spotlight")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let study = study {
                            Text(study.category.rawValue)
                                .font(.caption)
                                .foregroundColor(categoryColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(categoryColor.opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke(categoryColor.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Label("PubMed Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button(action: { showFullStudy.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.title3)
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: categoryColor))
            
            Text("Loading today's research...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("Finding the most relevant health insights for you")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private func studyContentSection(study: Study) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Study title and metadata
            VStack(alignment: .leading, spacing: 8) {
                Text(study.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Text("\(study.authors) • \(study.journal) (\(study.year))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            
            // Rotating takeaways section
            if !study.takeaways.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Key Insights")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(categoryColor)
                        
                        Spacer()
                        
                        Text("\(currentTakeawayIndex + 1)/\(study.takeaways.count)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Current takeaway with smooth transition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• \(study.takeaways[currentTakeawayIndex])")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        
                        // Progress indicator
                        HStack(spacing: 4) {
                            ForEach(0..<study.takeaways.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentTakeawayIndex ? categoryColor : Color.white.opacity(0.3))
                                    .frame(width: index == currentTakeawayIndex ? 20 : 6, height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: currentTakeawayIndex)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func actionButtonsSection(study: Study) -> some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 12) {
                // Open study button
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                            .font(.caption)
                        Text("Read Study")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(categoryColor)
                            .shadow(color: categoryColor.opacity(0.5), radius: 8, x: 0, y: 4)
                    )
                }
                
                // Bookmark button
                Button(action: onBookmark) {
                    HStack(spacing: 8) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.caption)
                        Text(isBookmarked ? "Saved" : "Save")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isBookmarked ? categoryColor : .white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isBookmarked ? categoryColor.opacity(0.2) : Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(categoryColor.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                // Refresh button
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            
            // Study source info
            HStack {
                Text("Source: PubMed Database")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                if let doi = study.doi {
                    Text("DOI: \(doi)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(20)
    }
    
    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("Unable to load study")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Check your connection and try again")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: onRefresh) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.orange)
                )
            }
        }
        .padding(40)
    }
    
    private func rotateTakeaways() {
        guard let study = study, !study.takeaways.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentTakeawayIndex = (currentTakeawayIndex + 1) % study.takeaways.count
        }
    }
}

// Preview
struct AdvancedStudyCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleStudy = Study(
            title: "Effect of Heart Rate Variability Biofeedback on Stress and Performance in Athletes",
            authors: "Smith et al.",
            journal: "Journal of Sports Medicine",
            year: "2023",
            doi: "10.1234/example.doi",
            url: URL(string: "https://example.com"),
            summary: "This study examines the impact of HRV biofeedback training on athletic performance and stress management.",
            takeaways: [
                "HRV biofeedback training improved stress resilience by 34% in athletes",
                "Performance metrics showed significant improvement after 8 weeks of training",
                "Participants reported better sleep quality and reduced anxiety levels"
            ],
            category: .training
        )
        
        VStack(spacing: 20) {
            AdvancedStudyCard(
                study: sampleStudy,
                isLoading: false,
                onRefresh: {},
                onBookmark: {},
                onOpen: {},
                isBookmarked: false
            )
            
            AdvancedStudyCard(
                study: nil,
                isLoading: true,
                onRefresh: {},
                onBookmark: {},
                onOpen: {},
                isBookmarked: false
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}