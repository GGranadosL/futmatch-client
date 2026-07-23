import SwiftUI

struct AppGateContainerView<Content: View>: View {
    @StateObject var viewModel: AppGateViewModel
    let content: Content

    init(viewModel: AppGateViewModel, @ViewBuilder content: () -> Content) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            switch viewModel.state {
            case .normal:
                EmptyView()

            case .maintenance(let title, let message):
                AppGateMaintenanceView(title: title, message: message)
                    .transition(.opacity)

            case .mandatoryUpdate(let title, let message, let updateLabel, let storeUrl):
                AppGateForceUpdateView(
                    title: title,
                    message: message,
                    updateButtonLabel: updateLabel,
                    storeUrl: storeUrl
                )
                .transition(.opacity)

            case .softUpdate(let title, let message, let updateLabel, let skipLabel, let storeUrl):
                AppGateSoftUpdateView(
                    title: title,
                    message: message,
                    updateButtonLabel: updateLabel,
                    skipButtonLabel: skipLabel,
                    storeUrl: storeUrl,
                    onSkip: { viewModel.dismissSoftUpdate() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .task { await viewModel.evaluate() }
    }
}
