import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var infinityPhase: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var figureOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background gradient matching app theme
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated icon area
                ZStack {
                    // Infinity symbol
                    InfinityShape()
                        .trim(from: 0, to: infinityPhase)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 120, height: 60)
                        .scaleEffect(pulseScale)
                    
                    // Two workout figures
                    HStack(spacing: 30) {
                        WorkoutFigure(offset: figureOffset, delay: 0)
                        WorkoutFigure(offset: figureOffset, delay: 0.5)
                    }
                    .offset(y: 80)
                }
                .frame(height: 200)
                
                // App name
                Text("Lifehack")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(isAnimating ? 1 : 0)
                
                // Loading indicator
                LoadingDots()
                    .padding(.top, 20)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Fade in app name
        withAnimation(.easeIn(duration: 1.0)) {
            isAnimating = true
        }
        
        // Infinity symbol drawing animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            infinityPhase = 1.0
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        // Figure bounce animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            figureOffset = -10
        }
    }
}

// MARK: - Infinity Symbol Shape
struct InfinityShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let center = CGPoint(x: width / 2, y: height / 2)
        
        // Draw infinity symbol using bezier curves
        path.move(to: CGPoint(x: center.x, y: center.y))
        
        // Left loop
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y),
            control1: CGPoint(x: center.x - width * 0.25, y: center.y - height * 0.5),
            control2: CGPoint(x: center.x - width * 0.25, y: center.y + height * 0.5)
        )
        
        // Right loop
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y),
            control1: CGPoint(x: center.x + width * 0.25, y: center.y + height * 0.5),
            control2: CGPoint(x: center.x + width * 0.25, y: center.y - height * 0.5)
        )
        
        return path
    }
}

// MARK: - Workout Figure
struct WorkoutFigure: View {
    let offset: CGFloat
    let delay: Double
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 4) {
            // Head
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 16, height: 16)
            
            // Body
            VStack(spacing: 2) {
                // Torso
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 12, height: 20)
                
                // Arms in workout position
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 3, height: 15)
                        .rotationEffect(.degrees(-30))
                        .offset(x: 3)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 3, height: 15)
                        .rotationEffect(.degrees(30))
                        .offset(x: -3)
                }
                .frame(width: 20)
                .offset(y: -20)
                
                // Legs
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 4, height: 18)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 4, height: 18)
                }
            }
        }
        .offset(y: animationOffset)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                animationOffset = offset
            }
        }
    }
}

// MARK: - Loading Dots
struct LoadingDots: View {
    @State private var animatingDot1 = false
    @State private var animatingDot2 = false
    @State private var animatingDot3 = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .scaleEffect(animatingDot1 ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0), value: animatingDot1)
            
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .scaleEffect(animatingDot2 ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: animatingDot2)
            
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .scaleEffect(animatingDot3 ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: animatingDot3)
        }
        .onAppear {
            animatingDot1 = true
            animatingDot2 = true
            animatingDot3 = true
        }
    }
}

#Preview {
    LaunchScreenView()
}
