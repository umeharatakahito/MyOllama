import SwiftUI

public struct MarkdownCanvasView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var viewMode: CanvasViewMode = .split
    @State private var showObsidianPicker: Bool = false
    @State private var saveStatusMessage: String? = nil

    public enum CanvasViewMode: String, CaseIterable, Identifiable {
        case edit = "✏️ 編集"
        case split = "🌗 分割"
        case preview = "👁️ プレビュー"

        public var id: String { rawValue }
    }

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Canvas Top Header Toolbar
            canvasHeaderBar

            Divider()

            // Main Canvas Editor & Preview Area
            if let _ = viewModel.activeCanvasDocument {
                HStack(spacing: 0) {
                    // Editor Panel
                    if viewMode == .edit || viewMode == .split {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Markdown エディター")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("随時編集可能・ずんだもんが参照中")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                            TextEditor(text: Binding(
                                get: { viewModel.activeCanvasDocument?.content ?? "" },
                                set: { newContent in
                                    viewModel.activeCanvasDocument?.content = newContent
                                    viewModel.activeCanvasDocument?.isModified = true
                                }
                            ))
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if viewMode == .split {
                        Divider()
                    }

                    // Preview Panel
                    if viewMode == .preview || viewMode == .split {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("リアルタイム プレビュー")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(viewModel.activeCanvasDocument?.content ?? "")
                                        .font(.system(size: 13))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                            }
                            .background(Color(nsColor: .textBackgroundColor))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                emptyCanvasPlaceholder
            }

            Divider()

            // Bottom Quick Brainstorming Action Bar
            quickBrainstormActionBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header Bar
    private var canvasHeaderBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.split.2x1.fill")
                .foregroundColor(.indigo)
                .font(.system(size: 16))

            if let doc = viewModel.activeCanvasDocument {
                TextField("ドキュメントタイトル", text: Binding(
                    get: { doc.title },
                    set: { newTitle in
                        viewModel.activeCanvasDocument?.title = newTitle
                        viewModel.activeCanvasDocument?.isModified = true
                    }
                ))
                .font(.system(size: 13, weight: .bold))
                .textFieldStyle(.plain)
                .frame(minWidth: 150, maxWidth: 280)

                if doc.isModified {
                    Text("● 未保存")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                }
            } else {
                Text("🎨 Markdown Canvas 壁打ち Studio")
                    .font(.system(size: 13, weight: .bold))
            }

            Spacer()

            // View Mode Picker (Edit / Split / Preview)
            Picker("", selection: $viewMode) {
                ForEach(CanvasViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)

            // Open from Obsidian Menu
            Menu {
                Button(action: {
                    viewModel.createNewCanvasDocument()
                }) {
                    Label("新規ノート作成", systemImage: "plus.doc.fill")
                }

                Divider()

                Text("📁 Obsidian (myollama) から開く")
                    .font(.caption2)

                ForEach(viewModel.openNotebook.obsidianNotes.prefix(15)) { note in
                    Button(action: {
                        viewModel.openCanvasWithObsidianNote(note)
                    }) {
                        Label(note.title, systemImage: "doc.text")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gearshape")
                    Text("ノートを開く")
                        .font(.caption)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Save to Obsidian Button
            Button(action: {
                let success = viewModel.saveActiveCanvasDocument()
                if success {
                    saveStatusMessage = "✅ 保存完了"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        saveStatusMessage = nil
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .foregroundColor(.cyan)
                    Text(saveStatusMessage ?? "Obsidianに保存")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCanvasDocument == nil)

            // Close Canvas Button
            Button(action: {
                withAnimation {
                    viewModel.isCanvasModeEnabled = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Canvasモードを閉じる")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Quick Brainstorm Action Bar
    private var quickBrainstormActionBar: some View {
        HStack(spacing: 8) {
            Text("💡 ずんだもんと壁打ち:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.indigo)

            brainstormActionButton(title: "💡 アイデアをブレスト", prompt: "このMarkdownノートの内容を元に、新しいアイデアや発展案を多角的に5つ提案してください。")
            brainstormActionButton(title: "🔍 構成・文章をレビュー", prompt: "このMarkdownノートを批判的にレビューし、論理の飛躍や改善点を具体的に指摘してください。")
            brainstormActionButton(title: "📝 要約・まとめを作成", prompt: "このMarkdownノートの重要事項を箇条書きで簡潔に要約してください。")
            brainstormActionButton(title: "🚀 企画書として洗練", prompt: "このMarkdownノートのアイデアを、より具体的で魅力的な企画・仕様書フォーマットにブラッシュアップしてください。")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.indigo.opacity(0.06))
    }

    private func brainstormActionButton(title: String, prompt: String) -> some View {
        Button(action: {
            viewModel.inputText = prompt
            viewModel.sendMessage()
        }) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Placeholder
    private var emptyCanvasPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "square.and.pencil")
                .font(.system(size: 44))
                .foregroundColor(.indigo.opacity(0.6))

            VStack(spacing: 4) {
                Text("Markdown Canvas を開いて壁打ちを開始")
                    .font(.headline)
                Text("既存のObsidianノートを選択するか、新しい企画・アイデアノートを作成して、\nフローティングずんだもんとリアルタイムに壁打ち議論できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.createNewCanvasDocument()
                }) {
                    Label("新規ノートを作成", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if let firstNote = viewModel.openNotebook.obsidianNotes.first {
                    Button(action: {
                        viewModel.openCanvasWithObsidianNote(firstNote)
                    }) {
                        Label("最新Obsidianノートを開く", systemImage: "doc.text.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
