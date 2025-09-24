import SwiftUI

struct JournalView: View {
    @Environment(\.themeTokens) private var theme
    @State private var draft: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Journal").font(.headline)
                        Text("Her kommer dagslogger, HRV-serier, humør og notater.")
                            .foregroundStyle(.secondary)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Ny notat").font(.headline)
                        TextEditor(text: $draft)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerSmall)
                                    .stroke(Color.white.opacity(0.15))
                            )
                            .scrollContentBackground(.hidden)
                        HStack {
                            Spacer()
                            Button {
                                // TODO: Persist draft (SwiftData / CoreData / CloudKit)
                                draft = ""
                            } label: {
                                Label("Lagre", systemImage: "tray.and.arrow.down")
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Journal. Draft length \(draft.count) characters.")
        }
        .navigationTitle("Journal")
    }
}

#Preview("JournalView") {
    NavigationView { JournalView().appThemeTokens(AppTheme.tokens()) }
}
