import SwiftUI

public struct VocabularyListView: View {
    @ObservedObject var learningService = EnglishLearningService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    @State private var newWord: String = ""
    @State private var newPhonetic: String = ""
    @State private var newMeaning: String = ""
    @State private var newExample: String = ""
    @State private var exportNotification: String? = nil

    public init() {}

    private var filteredItems: [VocabItem] {
        if searchText.isEmpty {
            return learningService.vocabularyItems
        } else {
            return learningService.vocabularyItems.filter {
                $0.word.localizedCaseInsensitiveContains(searchText) ||
                $0.meaning.localizedCaseInsensitiveContains(searchText)
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

            // Search and Filter Bar
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

            // Word List
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredItems) { item in
                        vocabItemRow(item: item)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(minWidth: 550, minHeight: 480)
        .sheet(isPresented: $showingAddSheet) {
            addWordSheet
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: "character.book.closed.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("📚 英語単語帳 (Vocabulary List)")
                    .font(.system(size: 14, weight: .bold))
                Text("総単語: \(learningService.vocabularyItems.count)件 (習得済: \(masteredCount)件)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Export to Obsidian Button
            Button(action: {
                let (success, path) = learningService.exportToObsidian()
                withAnimation {
                    if success {
                        exportNotification = "Obsidian (myollama/vocabulary.md) に保存しました！"
                    } else {
                        exportNotification = "保存に失敗しました"
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        exportNotification = nil
                    }
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
            .help("ObsidianのmyollamaフォルダにMarkdown単語帳としてエクスポート")

            // Add Word Button
            Button(action: {
                showingAddSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

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

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)

            TextField("単語や意味で検索...", text: $searchText)
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

    // MARK: - Vocab Item Row
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

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("登録されている単語がありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("画面上の英文をマウスで囲むか、上の「＋」ボタンで追加できます")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Add Word Sheet
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
}
