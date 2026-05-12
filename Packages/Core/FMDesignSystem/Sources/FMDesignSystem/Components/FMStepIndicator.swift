import SwiftUI

/// Step Progress Indicator for Onboarding
public struct FMStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepText: String?
    
    public init(currentStep: Int, totalSteps: Int, stepText: String? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.stepText = stepText
    }
    
    private var displayText: String {
        stepText ?? "Step \(currentStep) of \(totalSteps)"
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Step Counter
            Text(displayText)
                .font(FMTypography.captionMedium)
                .foregroundColor(FMColors.primary)
            
            // Progress Bar
            FMProgressBar(currentStep: currentStep, totalSteps: totalSteps)
        }
    }
}

/// Progress Bar Only (without text)
public struct FMProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    public init(currentStep: Int, totalSteps: Int) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(FMColors.primaryContainer)
                    .frame(height: 4)
                
                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(FMColors.primary)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        FMStepIndicator(currentStep: 1, totalSteps: 4, stepText: "Paso 1 de 4")
        FMStepIndicator(currentStep: 2, totalSteps: 4, stepText: "Step 2 of 4")
        FMProgressBar(currentStep: 3, totalSteps: 4)
        FMProgressBar(currentStep: 4, totalSteps: 4)
    }
    .padding()
}
