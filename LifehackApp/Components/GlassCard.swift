import SwiftUI

struct GlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        AppTheme.card {
            content()
        }
    }
}

#Preview("GlassCard") {
    GlassCard {
        VStack(alignment: .leading) {
            Text("Title").font(.headline)
            Text("Body text").font(.subheadline)
        }
    }
    .padding()
    .background(AppTheme.background.ignoresSafeArea())
}
    .padding()
}
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
