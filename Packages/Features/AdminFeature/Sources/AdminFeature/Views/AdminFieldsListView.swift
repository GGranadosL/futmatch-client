import SwiftUI
import FMDesignSystem

// MARK: - AdminFieldsListView

struct AdminFieldsListView: View {
    @StateObject private var viewModel: AdminFieldsViewModel
    @Environment(\.dismiss) private var dismiss

    private let factory: AdminDependencyFactory
    private let remoteConfig: AdminRemoteConfigProtocol
    @State private var selectedField: AdminFieldItem?

    init(
        viewModel: @autoclosure @escaping () -> AdminFieldsViewModel,
        factory: AdminDependencyFactory,
        remoteConfig: AdminRemoteConfigProtocol
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.factory = factory
        self.remoteConfig = remoteConfig
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(FMColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text("Canchas")
                    .font(FMTypography.titleLarge)
                    .foregroundColor(FMColors.onBackground)
            }
        }
        .task { await viewModel.load() }
        .navigationDestination(isPresented: Binding(
            get: { selectedField != nil },
            set: { if !$0 { selectedField = nil } }
        )) {
            if let field = selectedField {
                AdminFieldDetailView(
                    field: field,
                    maxImages: remoteConfig.maxFieldImages,
                    factory: factory,
                    onFieldUpdated: { viewModel.applyUpdatedField($0) }
                )
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            skeletonList
        case .loaded(let fields):
            fieldsList(fields)
        case .empty:
            FMEmptyStateCard(icon: "sportscourt.fill", message: "No hay canchas registradas")
                .padding(.horizontal, 24)
                .padding(.top, 32)
        case .failed(let message):
            FMFullScreenError(
                title: "Error",
                message: message,
                retryTitle: "Reintentar",
                onRetry: { Task { await viewModel.load() } }
            )
        }
    }

    /// Shown only on the first load when there is no cached data yet.
    private var skeletonList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header skeleton
                VStack(alignment: .leading, spacing: 8) {
                    FMSkeleton(cornerRadius: 6).frame(width: 180, height: 24)
                    FMSkeleton(cornerRadius: 4).frame(width: 260, height: 14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Card skeletons
                VStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        AdminFieldCardSkeleton()
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .disabled(true)
    }

    private func fieldsList(_ fields: [AdminFieldItem]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nuestras Canchas")
                        .font(FMTypography.headlineSmall)
                        .foregroundColor(FMColors.onBackground)
                    Text("Gestiona y visualiza complejos deportivos")
                        .font(FMTypography.bodySmall)
                        .foregroundColor(FMColors.onSurfaceVariant)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Cards
                LazyVStack(spacing: 16) {
                    ForEach(fields) { field in
                        AdminFieldCard(field: field) { selectedField = field }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .refreshable { await viewModel.load() }
    }
}
