import SwiftUI

public struct VocabularyListView: View {
    @ObservedObject var learningService = EnglishLearningService.shared
    @ObservedObject var historyService = TranslationHistoryService.shared
    @Environment(\.dismiss) private var dismiss

    public enum Tab: String, CaseIterable {
        case history = "🕒 翻訳・検索履歴"
        case vocabulary = "⭐️ 単語帳"
    }

    @State private var selectedTab: Tab = .history
    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    @State private var newWord: String = ""
    @State private var newPhonetic: String = ""
    @State private var newMeaning: String = ""
    @State private var newExample: String = ""
    @State private var exportNotification: String? = nil
    @State private var showingClearConfirm: Bool = false

    public init() {}

    // 単語帳フィルタ
    private var filteredVocabItems: [VocabItem] {
        if searchText.isEmpty {
            return learningService.vocabularyItems
        } else {
            return learningService.vocabularyItems.filter {
                $0.word.localizedCaseInsensitiveContains(searchText) ||
                $0.meaning.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // 履歴フィルタ
    private var filteredHistoryItems: [TranslationHistoryItem] {
        if searchText.isEmpty {
            return historyService.historyItems
        } else {
            return historyService.historyItems.filter {
                $0.sourceText.localizedCaseInsensitiveContains(searchText) ||
                $0.definition.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var masteredCount: Int {
        learningService.vocabularyItems.filter { $0.isMastered }.count
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Tab Selector Bar
            tabSelectorBar

            Divider()

            // Search Bar
            searchBar

            // Export Alert / Toast
            if let note = exportNotification {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(note)
                        .font(.caption2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main Content Body
            if selectedTab == .history {
                historyListView
            } else {
                vocabularyListView
            }
        }
        .frame(minWidth: 620, minHeight: 520)
        .sheet(isPresented: $showingAddSheet) {
            addWordSheet
        }
        .alert("翻訳履歴の全消去", isPresented: $showingClearConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("すべて消去", role: .destructive) {
                historyService.clearAllHistory()
            }
        } message: {
            Text("蓄積されたすべての翻訳・検索履歴を消去しますか？（単語帳に登録した単語は消えません）")
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: selectedTab == .history ? "clock.arrow.circlepath" : "character.book.closed.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab == .history ? "🕒 翻訳・検索履歴データベース" : "⭐️ 英語単語帳 (Vocabulary List)")
                    .font(.system(size: 14, weight: .bold))
                Text(selectedTab == .history ? "蓄積ログ: \(historyService.historyItems.count)件 (自動保存中)" : "総単語: \(learningService.vocabularyItems.count)件 (習得済: \(masteredCount)件)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Export to Obsidian Button
            Button(action: {
                if selectedTab == .history {
                    let (success, _) = historyService.exportToObsidian()
                    showNotification(success ? "Obsidian (myollama/translation_history.md) に履歴を保存しました！" : "保存に失敗しました")
                } else {
                    let (success, _) = learningService.exportToObsidian()
                    showNotification(success ? "Obsidian (myollama/vocabulary.md) に単語帳を保存しました！" : "保存に失敗しました")
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Obsidianに保存")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
                .foregroundColor(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("ObsidianのmyollamaフォルダにMarkdownとしてエクスポート")

            if selectedTab == .vocabulary {
                // Add Word Button
                Button(action: {
                    showingAddSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("単語追加")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                // Clear History Button
                Button(action: {
                    showingClearConfirm = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("履歴クリア")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(historyService.historyItems.isEmpty)
            }

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Tab Selector Bar
    private var tabSelectorBar: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))

                        Text(tab == .history ? "\(historyService.historyItems.count)" : "\(learningService.vocabularyItems.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(selectedTab == tab ? Color.cyan.opacity(0.3) : Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color.cyan.opacity(0.18) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .cyan : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)

            TextField(selectedTab == .history ? "過去に調べた英文や単語、日本語訳で検索..." : "単語や意味で検索...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 🕒 履歴リストビュー
    private var historyListView: some View {
        Group {
            if filteredHistoryItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "まだ翻訳・検索の履歴がありません" : "該当する履歴が見つかりません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("画面上で Cmd+Shift+S (範囲選択) や Cmd+Shift+E (選択テキスト) を実行すると自動でここに蓄積されます")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(filteredHistoryItems) { item in
                        historyItemRow(item: item)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - 🕒 履歴アイテム行
    private func historyItemRow(item: TranslationHistoryItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Bookmark (単語帳に追加) ボタン
            Button(action: {
                withAnimation {
                    historyService.toggleBookmark(for: item)
                }
            }) {
                Image(systemName: item.isBookmarked ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundColor(item.isBookmarked ? .yellow : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(item.isBookmarked ? "単語帳から削除" : "⭐️ 単語帳に追加")
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.sourceText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    if !item.phonetic.isEmpty {
                        Text(item.phonetic)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                    }

                    if !item.partOfSpeech.isEmpty {
                        Text(item.partOfSpeech)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }

                    // Native Pronunciation Button
                    Button(action: {
                        learningService.speakNativeEnglish(text: item.sourceText)
                    }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("ネイティブ発音を再生")

                    Spacer()

                    // Source Tag & Timestamp
                    Text(item.source)
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }

                if !item.definition.isEmpty {
                    Text(item.definition)
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(3)
                }
            }

            // Ask Chat for Grammar & Analysis
            Button(action: {
                dismiss()
                NotificationCenter.default.post(
                    name: Notification.Name("MyOllama.RequestEnglishAnalysis"),
                    object: item.sourceText
                )
            }) {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundColor(.indigo)
            }
            .buttonStyle(.plain)
            .help("チャットで詳細な文法・構文解説を展開")

            // Delete History Button
            Button(action: {
                historyService.deleteItem(id: item.id)
            }) {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - ⭐️ 単語帳リストビュー
    private var vocabularyListView: some View {
        Group {
            if filteredVocabItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "単語帳に登録された単語がありません" : "該当する単語が見つかりません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("履歴タブの「⭐️」を押すか、右上の「＋ 単語追加」から追加できます")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(filteredVocabItems) { item in
                        vocabItemRow(item: item)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - ⭐️ 単語帳アイテム行
    private func vocabItemRow(item: VocabItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox for Mastered
            Button(action: {
                learningService.toggleMastered(id: item.id)
            }) {
                Image(systemName: item.isMastered ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(item.isMastered ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.word)
                        .font(.system(size: 14, weight: .bold))

                    if !item.phonetic.isEmpty {
                        Text(item.phonetic)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if !item.partOfSpeech.isEmpty {
                        Text(item.partOfSpeech)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }

                    // Native Pronunciation Button
                    Button(action: {
                        learningService.speakNativeEnglish(text: item.word)
                    }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("ネイティブ発音を再生")
                }

                Text(item.meaning)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                if !item.exampleSentence.isEmpty {
                    Text("例: \(item.exampleSentence)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()

            // Delete Button
            Button(action: {
                learningService.deleteItem(id: item.id)
            }) {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - ➕ 単語追加シート
    private var addWordSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("➕ 英単語を手動追加")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("英単語 / フレーズ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: persistent", text: $newWord)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("発音記号 (任意)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: /pərˈsɪstənt/", text: $newPhonetic)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("日本語の意味")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: 粘り強い、持続する", text: $newMeaning)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("例文 (任意)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: He is persistent in his efforts.", text: $newExample)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    showingAddSheet = false
                }
                .buttonStyle(.bordered)

                Button("追加") {
                    if !newWord.isEmpty && !newMeaning.isEmpty {
                        learningService.addVocabularyItem(
                            word: newWord,
                            phonetic: newPhonetic,
                            meaning: newMeaning,
                            exampleSentence: newExample
                        )
                        newWord = ""
                        newPhonetic = ""
                        newMeaning = ""
                        newExample = ""
                        showingAddSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func showNotification(_ message: String) {
        withAnimation {
            exportNotification = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                exportNotification = nil
            }
        }
    }
}
