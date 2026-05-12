import SwiftUI

/// Circular progress ring displaying an OVR (Overall) score
/// Used in profile performance section
public struct FMOVRRing: View {
    let score: Int
    let maxScore: Int
    let label: String
    
    public init(score: Int, maxScore: Int = 100, label: String = "OVR") {
        self.score = score
        self.maxScore = maxScore
        self.label = label
    }
    
    private var progress: Double {
        Double(score) / Double(maxScore)
    }
    
    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(FMColors.outlineVariant.opacity(0.3), lineWidth: 6)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    FMColors.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Score + label
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(FMTypography.headlineLarge)
                    .foregroundColor(FMColors.onSurface)
                
                Text(label)
                    .font(FMTypography.labelSmall)
                    .foregroundColor(FMColors.onSurfaceVariant)
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - Preview
#Preview {
    FMOVRRing(score: 80)
        .padding()
}
