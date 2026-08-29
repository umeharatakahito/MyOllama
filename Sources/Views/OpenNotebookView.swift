import SwiftUI

public struct OpenNotebookView: View {
    @StateObject private var service = OpenNotebookService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Tab = .notebooks
    @State private var searchQuery: String = ""
    @State private var searchResults: [OpenNotebookSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var selectedNotebook: OpenNotebookItem? = nil
    @State private var sources: [OpenNotebookSource] = []
    @State private var isLoadingSources: Bool = false
    @State private var selectedSource: OpenNotebookSource? = nil
    @State private var selectedObsidianNote: ObsidianNoteItem? = nil
    @State private var obsidianContent: String = ""

    public enum Tab: String, CaseIterable, Identifiable {
        case notebooks = "📓 ノートブック"
        case obsidian = "💎 Obsidian"
        case search = "🔍 RAG検索"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Content Area
            HStack(spacing: 0) {
                // Left Sidebar / Navigation
                leftSidebar
                    .frame(width: 250)

                Divider()

                // Right Content / Preview
                rightPreviewArea
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    // MARK: - Header Bar (2-Row Layout with clear Close Button)
    private var headerBar: some View {
        VStack(spacing: 8) {
            // Row 1: Title & Close Button
            HStack(spacing: 10) {
                Image(systemName: "book.pages.fill")
                    .foregroundColor(.cyan)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Notebook / RAG ナレッジ管理")
                        .font(.headline)
                    Text("Obsidian Vault 取り込みデータと Open Notebook ベクトル知識ベース")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Prominent Close Button
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                        Text("チャットに戻る (Esc)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Escキーまたはクリックでチャット画面に戻ります")
            }

            // Row 2: Tabs & Status Badge
            HStack(spacing: 12) {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()

                // Server Status Badge & Start Button
                HStack(spacing: 8) {
                    Circle()
                        .fill(service.isServerRunning ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(service.isServerRunning ? "API 接続中 (5055)" : "API 停止中 (ローカル検索)")
                        .font(.caption2)
                        .foregroundColor(service.isServerRunning ? .green : .orange)

                    if !service.isServerRunning {
                        Button(action: { service.startServer() }) {
                            HStack(spacing: 4) {
                                if service.isStartingServer {
                                    ProgressView().controlSize(.mini)
                                    Text("起動中...")
                                } else {
                                    Image(systemName: "play.fill")
                                    Text("サーバー起動")
                                }
                            }
                            .font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(service.isStartingServer)
                    }

                    Button(action: {
                        Task {
                            await service.checkServerHealth()
                            service.loadObsidianNotes()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("状態を再取得")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .notebooks:
                notebooksListView
            case .obsidian:
                obsidianNotesListView
            case .search:
                searchControlView
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // Tab 1: Notebooks List
    private var notebooksListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ノートブック一覧 (\(service.notebooks.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(10)

            Divider()

            if service.notebooks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "books.vertical")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(service.isServerRunning ? "ノートブックがありません" : "サーバーが停止しています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(service.notebooks, id: \.id, selection: $selectedNotebook) { nb in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nb.name)
                            .font(.callout)
                            .fontWeight(.medium)
                        if let desc = nb.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(nb)
                }
                .listStyle(.sidebar)
                .onChange(of: selectedNotebook) { _, newNb in
                    if let nb = newNb {
                        loadSources(for: nb.id)
                    }
                }
            }
        }
    }

    // Tab 2: Obsidian Notes List
    private var obsidianNotesListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Obsidian Vault (\(service.obsidianNotes.count) 件)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(10)

            Divider()

            List(service.obsidianNotes, id: \.id, selection: $selectedObsidianNote) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(note.relPath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
                .tag(note)
            }
            .listStyle(.sidebar)
            .onChange(of: selectedObsidianNote) { _, note in
                if let note = note {
                    obsidianContent = service.readObsidianNoteContent(at: note.url) ?? "(読み込み失敗)"
                }
            }
        }
    }

    // Tab 3: Search Control View
    private var searchControlView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RAG 知識ベース検索")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                TextField("検索キーワードを入力...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }

                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if isSearching {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("ナレッジを検索中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            Text("結果 (\(searchResults.count) 件):")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            List(searchResults) { result in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(result.title)
                            .font(.caption)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        Spacer()
                        if let score = result.score {
                            Text(String(format: "%.2f", score))
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                    Text(result.content)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
        .padding(12)
    }

    // MARK: - Right Preview Area
    private var rightPreviewArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch selectedTab {
            case .notebooks:
                if let nb = selectedNotebook {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nb.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let desc = nb.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(nsColor: .windowBackgroundColor))

                        Divider()

                        // Sources in this Notebook
                        if isLoadingSources {
                            ProgressView("ソースを読み込み中...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if sources.isEmpty {
                            VStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "doc.text")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("このノートブックにはまだソースがありません")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(sources) { source in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(source.displayTitle)
                                            .font(.headline)
                                        Spacer()
                                        if source.embedded == true {
                                            Label("ベクトル化済", systemImage: "bolt.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    if let content = source.content {
                                        Text(content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(4)
                                    }
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                } else {
                    emptySelectionView(title: "ノートブックを選択してください")
                }

            case .obsidian:
                if let note = selectedObsidianNote {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.relPath)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(nsColor: .windowBackgroundColor))

                        Divider()

                        ScrollView {
                            Text(obsidianContent)
                                .font(.system(size: 13, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    emptySelectionView(title: "Obsidianノートを選択してください")
                }

            case .search:
                if let first = searchResults.first {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("検索ヒット詳細 (先頭)")
                                .font(.headline)
                            Text(first.title)
                                .font(.title3)
                                .fontWeight(.bold)
                            Divider()
                            Text(first.content)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                                .lineSpacing(4)
                        }
                        .padding(16)
                    }
                } else {
                    emptySelectionView(title: "キーワードを入力して検索してください")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func emptySelectionView(title: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "hand.point.left")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.4))
            Text(title)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadSources(for notebookId: String) {
        isLoadingSources = true
        Task {
            if let fetched = try? await service.fetchSources(for: notebookId) {
                self.sources = fetched
            } else {
                self.sources = []
            }
            self.isLoadingSources = false
        }
    }

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        Task {
            let res = await service.searchRAG(query: searchQuery, limit: 10)
            self.searchResults = res
            self.isSearching = false
        }
    }
}
