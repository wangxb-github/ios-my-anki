import SwiftUI
import AnkiKit
import AnkiBackend
import AnkiClients
import Dependencies

struct DeckListView: View {
    @Dependency(\.ankiBackend) var backend
    @Dependency(\.deckClient) var deckClient
    @ObservedObject private var collectionState = AppCollectionState.shared
    @AppStorage(DeckListHeatmapSettings.showKey) private var showDeckListHeatmap = true

    @State private var tree: [DeckTreeNode] = []
    @State private var isLoading = true
    @State private var deckToDelete: DeckTreeNode?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var heatmapRefreshID = 0
    @State private var hasLoadedHeatmap = false
    @State private var isExportingDeck = false
    @State private var exportedDeckFileURL: URL?
    @State private var showDeckExportShareSheet = false
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var quickReviewDeck: DeckInfo?
    @Namespace private var deckZoomNamespace
    var onDeckChanged: (() -> Void)? = nil

    private var aggregatedCounts: DeckCounts {
        tree.reduce(DeckCounts.zero) { acc, node in
            DeckCounts(
                newCount: acc.newCount + node.counts.newCount,
                learnCount: acc.learnCount + node.counts.learnCount,
                reviewCount: acc.reviewCount + node.counts.reviewCount
            )
        }
    }

    private var firstDueDeckInfo: DeckInfo? {
        guard let node = tree.first(where: { $0.counts.total > 0 }) ?? tree.first else {
            return nil
        }
        return DeckInfo(id: node.id, name: node.fullName, counts: node.counts)
    }

    init(onDeckChanged: (() -> Void)? = nil) {
        self.onDeckChanged = onDeckChanged
        let cachedTree = DeckTreeCache.load()
        _tree = State(initialValue: cachedTree)
        _isLoading = State(initialValue: true)
    }

    var body: some View {
        Group {
            if isLoading && tree.isEmpty {
                ProgressView()
            } else if tree.isEmpty {
                ContentUnavailableView(
                    L("deck_list_empty_title"),
                    systemImage: "rectangle.stack",
                    description: Text(L("deck_list_empty_desc"))
                )
            } else {
                List {
                    Section {
                        DeckListHeroSummaryView(
                            counts: aggregatedCounts,
                            canQuickStudy: firstDueDeckInfo != nil && aggregatedCounts.total > 0,
                            onQuickStudy: {
                                if let target = firstDueDeckInfo {
                                    quickReviewDeck = target
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if showDeckListHeatmap {
                        Section {
                            DeckListHeatmapCard(refreshID: heatmapRefreshID, showsExternalLoading: isLoading)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    Section {
                        ForEach(tree) { node in
                            DeckRowView(
                                node: node,
                                depth: 0,
                                isCollectionReady: collectionState.isReady,
                                zoomNamespace: deckZoomNamespace,
                                onDeckChanged: {
                                    Task { await loadDecks() }
                                    refreshHeatmap()
                                    onDeckChanged?()
                                },
                                onDeleteRequested: { node in
                                    deckToDelete = node
                                    showDeleteConfirm = true
                                },
                                onExportRequested: { node in
                                    Task { await exportDeck(node) }
                                }
                            )
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        Color.amgiBackground.ignoresSafeArea()
                        LiquidAuroraBackground(streak: aggregatedCounts.total > 0 ? 6 : 1)
                            .opacity(0.18)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: DeckInfo.self) { deck in
                    DeckDetailView(deck: deck)
                        .navigationTransition(.zoom(sourceID: deck.id, in: deckZoomNamespace))
                }
                .fullScreenCover(item: $quickReviewDeck) { deck in
                    ReviewView(deckId: deck.id) {
                        quickReviewDeck = nil
                        Task { await loadDecks() }
                        refreshHeatmap()
                        onDeckChanged?()
                    }
                }
                .refreshable {
                    await loadDecks()
                    refreshHeatmap()
                }
            }
        }
        .background(Color.amgiBackground)
        .navigationTitle(L("deck_list_nav_title"))
        .onReceive(NotificationCenter.default.publisher(for: AppUserStore.didChangeNotification)) { _ in
            Task {
                await loadDecks()
                refreshHeatmap()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppCollectionEvents.didResetNotification)) { _ in
            Task {
                await loadDecks()
                refreshHeatmap()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppCollectionEvents.didOpenNotification)) { _ in
            Task {
                await loadDecks()
                refreshHeatmap()
            }
        }
        .alert(
            L("deck_delete_confirm2_title"),
            isPresented: $showDeleteConfirm
        ) {
            Button(L("btn_confirm_delete"), role: .destructive) {
                Task { await deleteDeck() }
            }
            Button(L("btn_cancel"), role: .cancel) {}
        } message: {
            Text(L("deck_delete_confirm2_message", deckToDelete?.name ?? ""))
        }
        .alert(L("deck_action_error_title"), isPresented: $showDeleteError) {
            Button(L("btn_got_it"), role: .cancel) {}
        } message: {
            Text(deleteError ?? L("label_error_unknown"))
        }
        .alert(L("deck_action_error_title"), isPresented: $showExportError) {
            Button(L("btn_got_it"), role: .cancel) {}
        } message: {
            Text(exportError ?? L("label_error_unknown"))
        }
        .sheet(isPresented: $showDeckExportShareSheet) {
            if let url = exportedDeckFileURL {
                ShareSheet(items: [url])
            }
        }
        .task {
            await loadDecks()
            if !hasLoadedHeatmap {
                hasLoadedHeatmap = true
                refreshHeatmap()
            }
        }
        .onChange(of: collectionState.isReady) { _, isReady in
            guard isReady else { return }
            Task {
                await loadDecks()
                refreshHeatmap()
            }
        }
    }

    private func loadDecks() async {
        guard collectionState.isReady else {
            isLoading = tree.isEmpty
            return
        }

        isLoading = true
        do {
            let freshTree = try deckClient.fetchTree()
            tree = freshTree
            DeckTreeCache.save(freshTree)
        } catch {
            print("[DeckListView] Error loading decks: \(error)")
        }
        isLoading = false
    }

    private func deleteDeck() async {
        guard collectionState.isReady else { return }
        guard let node = deckToDelete else { return }
        do {
            try deckClient.delete(node.id)
            DeckDeletionMaintenance.resetHeatmapSelectionIfNeeded(deletedDeckID: node.id)

            do {
                try DeckDeletionMaintenance.cleanupUnusedMedia(using: backend)
            } catch {
                print("[DeckListView] Media cleanup after deck deletion failed: \(error)")
            }

            await loadDecks()
            refreshHeatmap()
            onDeckChanged?()
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
        }
        deckToDelete = nil
    }

    private func refreshHeatmap() {
        guard showDeckListHeatmap, collectionState.isReady else { return }
        heatmapRefreshID += 1
    }

    @MainActor
    private func exportDeck(_ node: DeckTreeNode) async {
        guard collectionState.isReady, !isExportingDeck else { return }
        exportedDeckFileURL = nil
        isExportingDeck = true
        defer { isExportingDeck = false }

        let configuration = ImportHelper.ExportPackageConfiguration.deck(
            deckID: node.id,
            deckName: node.fullName,
            includeScheduling: true,
            includeDeckConfigs: true,
            includeMedia: true,
            legacy: false
        )
        let backend = self.backend
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try ImportHelper.exportPackage(backend: backend, configuration: configuration)
            }.value
            await MainActor.run {
                exportedDeckFileURL = url
                showDeckExportShareSheet = true
            }
        } catch {
            await MainActor.run {
                exportError = L("deck_export_error", error.localizedDescription)
                showExportError = true
            }
        }
    }
}

// MARK: - DeckRowView

private struct DeckRowView: View {
    @Dependency(\.deckClient) var deckClient
    let node: DeckTreeNode
    let depth: Int
    let isCollectionReady: Bool
    let zoomNamespace: Namespace.ID
    let onDeckChanged: () -> Void
    let onDeleteRequested: (DeckTreeNode) -> Void
    let onExportRequested: (DeckTreeNode) -> Void

    @State private var showRenamePrompt = false
    @State private var renameText = ""
    @State private var actionError: String?
    @State private var showActionError = false

    var body: some View {
        deckContent
        .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1.0 : 0.82)
                .scaleEffect(phase.isIdentity ? 1.0 : 0.97)
        }
        .listRowBackground(Color.amgiSurfaceElevated)
        .alert(L("deck_rename_alert_title"), isPresented: $showRenamePrompt) {
            TextField(L("deck_rename_alert_placeholder"), text: $renameText)
            Button(L("btn_cancel"), role: .cancel) {}
            Button(L("btn_save")) {
                Task { await renameDeck() }
            }
        } message: {
            Text(L("deck_rename_alert_message"))
        }
        .alert(L("deck_action_error_title"), isPresented: $showActionError) {
            Button(L("btn_got_it"), role: .cancel) {}
        } message: {
            Text(actionError ?? L("label_error_unknown"))
        }
    }

    @ViewBuilder
    private var deckContent: some View {
        if node.children.isEmpty {
            leafRow
        } else {
            parentRow
        }
    }

    @ViewBuilder
    private var leafRow: some View {
        NavigationLink(value: deckInfo) {
            rowContent
        }
        .matchedTransitionSource(id: deckInfo.id, in: zoomNamespace)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            swipeButtons
        }
    }

    @ViewBuilder
    private var parentRow: some View {
        if depth == 0 {
            DisclosureGroup {
                childrenList
            } label: {
                NavigationLink(value: deckInfo) {
                    rowContent
                }
                .matchedTransitionSource(id: deckInfo.id, in: zoomNamespace)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                swipeButtons
            }
        } else {
            DisclosureGroup {
                childrenList
            } label: {
                NavigationLink(value: deckInfo) {
                    rowContent
                }
                .matchedTransitionSource(id: deckInfo.id, in: zoomNamespace)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                swipeButtons
            }
        }
    }

    @ViewBuilder
    private var swipeButtons: some View {
        Button {
            onExportRequested(node)
        } label: {
            Label(L("deck_row_export"), systemImage: "square.and.arrow.up")
        }
        .tint(Color.amgiPositive)
        .disabled(!isCollectionReady)

        Button {
            renameText = node.name
            showRenamePrompt = true
        } label: {
            Label(L("deck_row_rename"), systemImage: "pencil")
        }
        .tint(Color.amgiAccent)
        .disabled(!isCollectionReady)

        Button(role: .destructive) {
            onDeleteRequested(node)
        } label: {
            Label(L("deck_row_delete"), systemImage: "trash")
        }
        .disabled(!isCollectionReady)
    }

    private var childrenList: some View {
        ForEach(node.children) { child in
            DeckRowView(
                node: child,
                depth: depth + 1,
                isCollectionReady: isCollectionReady,
                zoomNamespace: zoomNamespace,
                onDeckChanged: onDeckChanged,
                onDeleteRequested: onDeleteRequested,
                onExportRequested: onExportRequested
            )
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            rowLeadingIcon
            VStack(alignment: .leading, spacing: 5) {
                Text(node.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.amgiTextPrimary)
                    .lineLimit(1)
                if node.counts.total > 0 {
                    DeckMiniProgressBar(counts: node.counts)
                }
            }
            Spacer(minLength: 8)
            DeckCountsView(counts: node.counts)
        }
        .padding(.vertical, 4)
    }

    private var rowLeadingIcon: some View {
        let hasDue = node.counts.total > 0
        let isParent = !node.children.isEmpty
        let iconName = isParent ? "rectangle.stack.fill" : (hasDue ? "menucard.fill" : "checkmark.seal.fill")
        let tintColor = hasDue ? Color.amgiAccent : Color.amgiRatingGood
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tintColor.opacity(0.15))
                .frame(width: 34, height: 34)
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tintColor)
        }
    }

    private var deckInfo: DeckInfo {
        DeckInfo(id: node.id, name: node.fullName, counts: node.counts)
    }

    private func renameDeck() async {
        guard isCollectionReady else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try deckClient.rename(node.id, trimmed)
            onDeckChanged()
        } catch {
            actionError = error.localizedDescription
            showActionError = true
        }
    }
}

// MARK: - 首页顶部液态玻璃总览英雄卡片

private struct DeckListHeroSummaryView: View {
    let counts: DeckCounts
    let canQuickStudy: Bool
    let onQuickStudy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            metricsRow
            if counts.total > 0 {
                DeckMiniProgressBar(counts: counts, barHeight: 6)
            }
            if canQuickStudy {
                quickStudyButton
            }
        }
        .amgiCard(elevated: true)
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: counts.total > 0 ? "sparkles" : "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(counts.total > 0 ? Color.amgiAccent : Color.amgiRatingGood)
                Text(counts.total > 0 ? "今日学习概览" : "今日任务已全部完成")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.amgiTextPrimary)
            }
            Spacer()
            if counts.total > 0 {
                Text("共 \(counts.total) 张待学")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.amgiAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.amgiAccent.opacity(0.14), in: Capsule())
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            heroStatTile(title: L("deck_detail_count_new"), value: counts.newCount, color: .amgiAccent, icon: "plus.circle.fill")
            heroStatTile(title: L("deck_detail_count_learning"), value: counts.learnCount, color: .amgiRatingHard, icon: "flame.fill")
            heroStatTile(title: L("deck_detail_count_review"), value: counts.reviewCount, color: .amgiRatingGood, icon: "arrow.triangle.2.circlepath.circle.fill")
        }
    }

    private func heroStatTile(title: String, value: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.amgiTextSecondary)
                    .lineLimit(1)
            }
            Text("\(value)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.26), lineWidth: 1)
        )
    }

    private var quickStudyButton: some View {
        Button {
            onQuickStudy()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("立即开始极速复习")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(Glass.regular.tint(Color.amgiAccent).interactive(), in: .capsule)
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: Color.amgiAccent.opacity(0.32), radius: 10, y: 4)
    }
}

// MARK: - 牌组三色比例微缩能量条

private struct DeckMiniProgressBar: View {
    let counts: DeckCounts
    var barHeight: CGFloat = 4

    var body: some View {
        let total = max(1, counts.total)
        let newRatio = CGFloat(counts.newCount) / CGFloat(total)
        let learnRatio = CGFloat(counts.learnCount) / CGFloat(total)
        let revRatio = CGFloat(counts.reviewCount) / CGFloat(total)

        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 2) {
                if counts.newCount > 0 {
                    Capsule()
                        .fill(Color.amgiAccent)
                        .frame(width: max(6, w * newRatio))
                }
                if counts.learnCount > 0 {
                    Capsule()
                        .fill(Color.amgiRatingHard)
                        .frame(width: max(6, w * learnRatio))
                }
                if counts.reviewCount > 0 {
                    Capsule()
                        .fill(Color.amgiRatingGood)
                        .frame(width: max(6, w * revRatio))
                }
            }
        }
        .frame(height: barHeight)
        .frame(maxWidth: 180)
    }
}
