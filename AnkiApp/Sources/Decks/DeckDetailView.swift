import SwiftUI
import AnkiKit
import AnkiBackend
import AnkiClients
import Dependencies

struct DeckDetailView: View {
    let deck: DeckInfo
    @Dependency(\.ankiBackend) var backend
    @Dependency(\.deckClient) var deckClient
    @ObservedObject private var collectionState = AppCollectionState.shared
    @State private var counts: DeckCounts = .zero
    @State private var childDecks: [DeckTreeNode] = []
    @State private var showReview = false
    @State private var showConfig = false
    @State private var showTemplateManager = false
    @State private var showAddNote = false
    @State private var showAddImageOcclusion = false
    @State private var selectedChildDeck: DeckTreeNode?
    @State private var renameText = ""
    @State private var showRenamePrompt = false
    @State private var showDeleteConfirm = false
    @State private var actionError: String?
    @State private var showActionError = false
    @State private var showStats = false
    @State private var showBrowse = false
    @State private var showAddSubdeck = false
    @State private var newSubdeckName = ""
    @State private var isExportingDeck = false
    @State private var exportedDeckFileURL: URL?
    @State private var showDeckExportShareSheet = false
    @State private var exportError: String?
    @State private var showExportError = false
    @Namespace private var studyZoomNamespace

    init(deck: DeckInfo) {
        self.deck = deck
        _counts = State(initialValue: deck.counts)
        _childDecks = State(initialValue: Self.cachedChildren(parentId: deck.id))
    }

    private var shortTitle: String {
        String(deck.name.split(separator: "::", omittingEmptySubsequences: true).last ?? Substring(deck.name))
    }

    var body: some View {
        List {
            countsSection
            studySection

            if !childDecks.isEmpty {
                subdecksSection
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                Color.amgiBackground.ignoresSafeArea()
                LiquidAuroraBackground(streak: counts.total > 0 ? 5 : 1)
                    .opacity(0.18)
            }
        }
        .navigationTitle(shortTitle)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showBrowse = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .accessibilityLabel(L("deck_detail_browse"))
                .disabled(!collectionState.isReady)

                Button {
                    showStats = true
                } label: {
                    Image(systemName: "chart.bar")
                }
                .accessibilityLabel(L("deck_detail_stats"))
                .disabled(!collectionState.isReady)

                Menu {
                    Button {
                        showAddNote = true
                    } label: {
                        Label(L("browse_add_note"), systemImage: "note.text.badge.plus")
                    }

                    Button {
                        showAddImageOcclusion = true
                    } label: {
                        Label(L("browse_add_image_occlusion"), systemImage: "rectangle.dashed.badge.record")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L("browse_add_accessibility"))
                .disabled(!collectionState.isReady)

                Menu {
                    Button {
                        newSubdeckName = ""
                        showAddSubdeck = true
                    } label: {
                        Label(L("deck_detail_add_subdeck"), systemImage: "rectangle.stack.badge.plus")
                    }

                    Button {
                        showTemplateManager = true
                    } label: {
                        Label(L("deck_template_nav_title"), systemImage: "square.on.square")
                    }

                    Button {
                        showConfig = true
                    } label: {
                        Label(L("deck_config_title"), systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(!collectionState.isReady)
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteView(
                onSave: {
                    Task { await loadCounts() }
                },
                preselectedDeckId: deck.id
            )
        }
        .fullScreenCover(isPresented: $showAddImageOcclusion) {
            AddImageOcclusionNoteView(
                onSave: {
                    Task { await loadCounts() }
                },
                preselectedDeckId: deck.id
            )
        }
        .sheet(isPresented: $showConfig) {
            DeckConfigView(deckId: deck.id) {
                showConfig = false
            }
        }
        .sheet(isPresented: $showTemplateManager) {
            NavigationStack {
                DeckTemplateListView()
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            ReviewView(deckId: deck.id) {
                showReview = false
                Task { await loadCounts() }
            }
            .navigationTransition(.zoom(sourceID: "study-\(deck.id)", in: studyZoomNamespace))
        }
        .sheet(isPresented: $showStats) {
            NavigationStack {
                StatsDashboardView(initialDeckID: deck.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L("common_done")) { showStats = false }
                                .amgiToolbarTextButton(tone: .neutral)
                        }
                    }
            }
        }
        .sheet(isPresented: $showBrowse) {
            NavigationStack {
                BrowseView(preselectedDeck: deck)
            }
        }
        .alert(L("deck_detail_add_subdeck"), isPresented: $showAddSubdeck) {
            TextField(L("deck_detail_add_subdeck_placeholder"), text: $newSubdeckName)
                .autocorrectionDisabled()
            Button(L("btn_cancel"), role: .cancel) {}
            Button(L("btn_save")) {
                Task { await createSubdeck() }
            }
        } message: {
            Text(L("deck_detail_add_subdeck_message"))
        }
        .alert(L("deck_rename_alert_title"), isPresented: $showRenamePrompt) {
            TextField(L("deck_rename_alert_placeholder"), text: $renameText)
            Button(L("btn_cancel"), role: .cancel) {}
            Button(L("btn_save")) {
                Task { await renameChildDeck() }
            }
        } message: {
            Text(L("deck_rename_alert_message"))
        }
        .alert(
            L("deck_delete_confirm2_title"),
            isPresented: $showDeleteConfirm
        ) {
            Button(L("btn_confirm_delete"), role: .destructive) {
                Task { await deleteChildDeck() }
            }
            Button(L("btn_cancel"), role: .cancel) {}
        } message: {
            Text(L("deck_delete_confirm2_message", selectedChildDeck?.name ?? ""))
        }
        .alert(L("deck_action_error_title"), isPresented: $showActionError) {
            Button(L("btn_got_it"), role: .cancel) {}
        } message: {
            Text(actionError ?? L("label_error_unknown"))
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
            guard collectionState.isReady else { return }
            await loadCounts()
            await loadChildren()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppCollectionEvents.didOpenNotification)) { _ in
            Task {
                await loadCounts()
                await loadChildren()
            }
        }
        .onChange(of: collectionState.isReady) { _, isReady in
            guard isReady else { return }
            Task {
                await loadCounts()
                await loadChildren()
            }
        }
    }

    // MARK: - Extracted Sub-Views

    private var countsSection: some View {
        Section {
            HStack(spacing: 10) {
                detailStatBox(
                    title: L("deck_detail_count_new"),
                    value: counts.newCount,
                    color: .amgiAccent,
                    icon: "plus.circle.fill"
                )
                detailStatBox(
                    title: L("deck_detail_count_learning"),
                    value: counts.learnCount,
                    color: .amgiRatingHard,
                    icon: "flame.fill"
                )
                detailStatBox(
                    title: L("deck_detail_count_review"),
                    value: counts.reviewCount,
                    color: .amgiRatingGood,
                    icon: "arrow.triangle.2.circlepath.circle.fill"
                )
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func detailStatBox(title: String, value: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.amgiTextSecondary)
                    .lineLimit(1)
            }
            Text("\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.32), lineWidth: 1)
        )
    }

    private var studySection: some View {
        let canStudy = collectionState.isReady && counts.total > 0
        let buttonTint = canStudy ? Color.amgiAccent : Color.gray.opacity(0.5)
        return Section {
            Button {
                showReview = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: canStudy ? "play.fill" : "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(L("deck_detail_study_now"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if counts.total > 0 {
                        Text("(\(counts.total))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(Glass.regular.tint(buttonTint).interactive(), in: .capsule)
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: canStudy ? Color.amgiAccent.opacity(0.35) : .clear, radius: 12, y: 4)
            .matchedTransitionSource(id: "study-\(deck.id)", in: studyZoomNamespace)
            .disabled(!canStudy)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var subdecksSection: some View {
        Section(L("deck_detail_subdecks")) {
            ForEach(childDecks) { child in
                NavigationLink(value: DeckInfo(id: child.id, name: child.fullName, counts: child.counts)) {
                    HStack {
                        Text(child.name)
                            .amgiFont(.body)
                            .foregroundStyle(Color.amgiTextPrimary)
                        Spacer()
                        DeckCountsView(counts: child.counts)
                    }
                }
                .listRowBackground(Color.amgiSurfaceElevated)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        Task { await exportDeck(child) }
                    } label: {
                        Label(L("deck_row_export"), systemImage: "square.and.arrow.up")
                    }
                    .tint(Color.amgiPositive)
                    .disabled(!collectionState.isReady)

                    Button {
                        selectedChildDeck = child
                        renameText = child.name
                        showRenamePrompt = true
                    } label: {
                        Label(L("deck_row_rename"), systemImage: "pencil")
                    }
                    .tint(Color.amgiAccent)
                    .disabled(!collectionState.isReady)

                    Button(role: .destructive) {
                        selectedChildDeck = child
                        showDeleteConfirm = true
                    } label: {
                        Label(L("deck_row_delete"), systemImage: "trash")
                    }
                    .disabled(!collectionState.isReady)
                }
            }
        }
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

    private func loadCounts() async {
        guard collectionState.isReady else { return }
        do {
            counts = try deckClient.countsForDeck(deck.id)
            print("[DeckDetail] Counts for '\(deck.name)' (\(deck.id)): new=\(counts.newCount), learn=\(counts.learnCount), review=\(counts.reviewCount)")
        } catch {
            print("[DeckDetail] Error loading counts for '\(deck.name)': \(error)")
            counts = .zero
        }
    }

    private func loadChildren() async {
        guard collectionState.isReady else { return }
        do {
            let tree = try deckClient.fetchTree()
            childDecks = findChildren(in: tree, parentId: deck.id)
        } catch {
            childDecks = []
        }
    }

    private func findChildren(in nodes: [DeckTreeNode], parentId: Int64) -> [DeckTreeNode] {
        for node in nodes {
            if node.id == parentId { return node.children }
            let found = findChildren(in: node.children, parentId: parentId)
            if !found.isEmpty { return found }
        }
        return []
    }

    private func renameChildDeck() async {
        guard collectionState.isReady else { return }
        guard let child = selectedChildDeck else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try deckClient.rename(child.id, trimmed)
            await loadChildren()
            await loadCounts()
        } catch {
            actionError = error.localizedDescription
            showActionError = true
        }
    }

    private func deleteChildDeck() async {
        guard collectionState.isReady else { return }
        guard let child = selectedChildDeck else { return }
        do {
            try deckClient.delete(child.id)
            DeckDeletionMaintenance.resetHeatmapSelectionIfNeeded(deletedDeckID: child.id)

            do {
                try DeckDeletionMaintenance.cleanupUnusedMedia(using: backend)
            } catch {
                print("[DeckDetailView] Media cleanup after deck deletion failed: \(error)")
            }

            selectedChildDeck = nil
            await loadChildren()
            await loadCounts()
        } catch {
            actionError = error.localizedDescription
            showActionError = true
        }
    }

    private func createSubdeck() async {
        guard collectionState.isReady else { return }
        let trimmed = newSubdeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let fullName = "\(deck.name)::\(trimmed)"
        do {
            _ = try deckClient.create(fullName)
            await loadChildren()
        } catch {
            actionError = error.localizedDescription
            showActionError = true
        }
    }

    private static func cachedChildren(parentId: Int64) -> [DeckTreeNode] {
        findCachedChildren(in: DeckTreeCache.load(), parentId: parentId)
    }

    private static func findCachedChildren(in nodes: [DeckTreeNode], parentId: Int64) -> [DeckTreeNode] {
        for node in nodes {
            if node.id == parentId { return node.children }
            let found = findCachedChildren(in: node.children, parentId: parentId)
            if !found.isEmpty { return found }
        }
        return []
    }
}
