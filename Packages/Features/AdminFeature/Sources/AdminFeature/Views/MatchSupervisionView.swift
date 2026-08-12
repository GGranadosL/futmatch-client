import SwiftUI
import FMDesignSystem

// MARK: - MatchSupervisionView

struct MatchSupervisionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MatchSupervisionViewModel

    @State private var activeDropdownId: String? = nil
    @State private var showSuccessToast = false

    /// Called after the success toast finishes — use to pop past the detail screen.
    /// Falls back to a single `dismiss()` when nil.
    var onCompleted: (() -> Void)?

    init(viewModel: MatchSupervisionViewModel, onCompleted: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                bestPlayerSection
                goalsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(FMColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMStickyActionBar(
                title: L10n.MatchSupervision.finalizeButton,
                isLoading: viewModel.isCompleting,
                isEnabled: viewModel.canFinalize,
                action: { Task { await viewModel.finalizeMatch() } }
            )
        }
        .navigationTitle(L10n.MatchSupervision.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
        }
        .alert(
            L10n.MatchSupervision.finalizeTitle,
            isPresented: Binding(
                get: { viewModel.completeError != nil },
                set: { if !$0 { viewModel.clearCompleteError() } }
            )
        ) {
            Button(L10n.Common.cancel, role: .cancel) { viewModel.clearCompleteError() }
        } message: {
            Text(viewModel.completeError ?? "")
        }
        .fmToast(L10n.MatchSupervision.completedSuccess, isPresented: $showSuccessToast, style: .success)
        .onChange(of: viewModel.completeSucceeded) { succeeded in
            guard succeeded else { return }
            showSuccessToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if let onCompleted {
                    onCompleted()
                } else {
                    dismiss()
                }
            }
        }
        .task { await viewModel.subscribeToPlayers() }
        .onAppear { viewModel.startEndTimeMonitoring() }
        .onDisappear { viewModel.stopEndTimeMonitoring() }
    }

    // MARK: - Best Player Picker

    private var bestPlayerSection: some View {
        let options = viewModel.allPlayers.map {
            FMSimpleOption(id: $0.playerId, displayName: $0.name)
        }
        let selectedBinding = Binding<FMSimpleOption?>(
            get: {
                guard let id = viewModel.bestPlayerId else { return nil }
                return options.first { $0.id == id }
            },
            set: { viewModel.setBestPlayer($0?.id) }
        )

        return FMDropdownField(
            label: L10n.MatchSupervision.bestPlayer,
            dropdownId: "bestPlayer",
            selectedOption: selectedBinding,
            activeDropdownId: $activeDropdownId,
            options: options
        )
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.MatchSupervision.goalsPerPlayer)
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onBackground)

            if viewModel.playersError != nil {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(FMColors.error)
                        Text(L10n.MatchSupervision.playersLoadError)
                            .font(FMTypography.bodySmall)
                            .foregroundColor(FMColors.onSurface)
                        Spacer()
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.errorContainer))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.error.opacity(0.3), lineWidth: 1))
            } else {
                // Teams are never empty — external rows are always there from init.
                // When registered players haven't loaded yet we show skeleton rows
                // above the external row inside each team card.
                teamGoalsSection(name: L10n.AdminMatchDetail.teamA, players: viewModel.teamAPlayers,
                                 showSkeleton: !viewModel.registeredPlayersLoaded)
                teamGoalsSection(name: L10n.AdminMatchDetail.teamB, players: viewModel.teamBPlayers,
                                 showSkeleton: !viewModel.registeredPlayersLoaded)
            }
        }
    }

    // MARK: - Team Goals Section

    private func teamGoalsSection(name: String, players: [AdminMatchPlayer], showSkeleton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(name)
                    .font(FMTypography.labelLarge)
                    .foregroundColor(FMColors.onSurfaceVariant)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(FMColors.surfaceContainerLow)

            // Skeleton rows while registered players load — external row is always below.
            if showSkeleton {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonPlayerRow
                    Divider().padding(.leading, 72)
                }
            }

            ForEach(players) { player in
                playerGoalRow(player: player)
                if player.id != players.last?.id {
                    Divider().padding(.leading, 72)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(FMColors.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMColors.outlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var skeletonPlayerRow: some View {
        HStack(spacing: 12) {
            Circle().fill(FMColors.surfaceContainerHigh).frame(width: 44, height: 44)
            RoundedRectangle(cornerRadius: 4).fill(FMColors.surfaceContainerHigh)
                .frame(height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: 4).fill(FMColors.surfaceContainerHigh)
                .frame(width: 88, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .redacted(reason: .placeholder)
    }

    // MARK: - Player Goal Row

    private func playerGoalRow(player: AdminMatchPlayer) -> some View {
        let isAbsent = viewModel.isAbsent(player)
        return HStack(spacing: 12) {
            playerAvatar(player: player)
                .opacity(isAbsent ? 0.4 : 1)

            Text(player.isExternal || player.name.isEmpty
                 ? L10n.MatchSupervision.externalPlayer
                 : player.name)
                .font(FMTypography.bodyMedium)
                .foregroundColor(player.isExternal ? FMColors.onTertiaryContainer : FMColors.onSurface)
                .strikethrough(isAbsent, color: FMColors.onSurfaceVariant)
                .opacity(isAbsent ? 0.5 : 1)
                .lineLimit(1)

            Spacer()

            // External players can't be absent — attendance only applies to enrolled users.
            if !player.isExternal {
                absenceToggle(player: player, isAbsent: isAbsent)
            }

            if isAbsent {
                absentBadge
            } else {
                goalStepper(player: player)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(player.isExternal ? FMColors.tertiaryContainer.opacity(0.4) : Color.clear)
    }

    // MARK: - Absence Toggle

    private func absenceToggle(player: AdminMatchPlayer, isAbsent: Bool) -> some View {
        Button {
            viewModel.toggleAbsence(for: player)
        } label: {
            Image(systemName: isAbsent ? "person.fill.xmark" : "person.fill.checkmark")
                .font(.system(size: 18))
                .foregroundColor(isAbsent ? FMColors.error : FMColors.onSurfaceVariant.opacity(0.6))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAbsent ? L10n.MatchSupervision.markPresent : L10n.MatchSupervision.markAbsent)
    }

    private var absentBadge: some View {
        Text(L10n.MatchSupervision.absentBadge)
            .font(FMTypography.labelMedium)
            .foregroundColor(FMColors.error)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(FMColors.errorContainer))
    }

    // MARK: - Player Avatar

    private func playerAvatar(player: AdminMatchPlayer) -> some View {
        Group {
            if let url = player.avatarUrl {
                FMRemoteImage(urlString: url) {
                    defaultAvatar(isExternal: player.isExternal)
                }
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                defaultAvatar(isExternal: player.isExternal)
            }
        }
    }

    private func defaultAvatar(isExternal: Bool) -> some View {
        Circle()
            .fill(isExternal ? FMColors.tertiaryContainer : FMColors.surfaceContainerHigh)
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isExternal ? FMColors.tertiary : FMColors.onSurfaceVariant)
            )
    }

    // MARK: - Goal Stepper

    private func goalStepper(player: AdminMatchPlayer) -> some View {
        HStack(spacing: 0) {
            Button {
                viewModel.removeGoal(from: player)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(FMColors.onSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("\(viewModel.goalCount(for: player))")
                .font(FMTypography.titleLarge)
                .foregroundColor(FMColors.onSurface)
                .frame(minWidth: 32, alignment: .center)

            Button {
                viewModel.addGoal(to: player)
            } label: {
                Image("soccerBall", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
