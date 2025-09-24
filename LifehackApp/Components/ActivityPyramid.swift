import SwiftUI

struct ActivityPyramid: View {
    var mets: Double // 0..? scale; we'll map 0..12 to height

    private var normalized: Double { min(max(mets / 12.0, 0), 1) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Sand ground
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.sRGB, red: 0.93, green: 0.86, blue: 0.72, opacity: 1))
                .frame(height: 8)
                .offset(y: -2)
            // Pyramid
            PyramidShape(progress: normalized)
                .fill(LinearGradient(colors: [Color(.sRGB, red: 0.88, green: 0.78, blue: 0.58, opacity: 1), Color(.sRGB, red: 0.76, green: 0.64, blue: 0.42, opacity: 1)], startPoint: .top, endPoint: .bottom))
                .overlay(PyramidShape(progress: normalized).stroke(.brown.opacity(0.35), lineWidth: 1))
            // Palm
            Image(systemName: "tree.palm")
                .font(.system(size: 28))
                .foregroundStyle(.green)
                .offset(x: 40, y: -12)
        }
        .frame(height: 120)
        .accessibilityLabel("Activity pyramid")
        .accessibilityValue("METs \(String(format: "%.1f", mets))")
    }

    private struct PyramidShape: Shape {
        var progress: Double // 0..1 controls height
        func path(in rect: CGRect) -> Path {
            let height = rect.height * progress
            let baseY = rect.maxY
            let topY = baseY - height
            let baseInset = max(0, (rect.height - height) * 0.4)
            let leftBase = CGPoint(x: rect.minX + baseInset, y: baseY)
            let rightBase = CGPoint(x: rect.maxX - baseInset, y: baseY)
            let top = CGPoint(x: rect.midX, y: topY)
            var p = Path()
            p.move(to: leftBase)
            p.addLine(to: top)
            p.addLine(to: rightBase)
            p.addLine(to: leftBase)
            return p
        }
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ActivityPyramid(mets: 2)
        ActivityPyramid(mets: 8)
        ActivityPyramid(mets: 12)
    }
    .padding()
}
