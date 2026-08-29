import SwiftUI

public struct MemoryManagerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isExtracting: Bool = false
    @State private var statusMessage: String? = nil

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("🧠 パーソナル長期記憶（メモリー）")
                        .font(.headline)
                    Text("あなたの性格・好み・重要事項・会話の文脈を永続的に記録し、常に考慮して対話します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("完了") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Action Banner (Extract from chat)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("✨ 現在の会話から記憶を自動抽出")
                                    .font(.system(size: 13, weight: .bold))
                                Text("これまでのやりとりから、あなたの性格・好み・決定事項をAIが分析して記憶に追加・整理します")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            Button(action: {
                                Task {
                                    isExtracting = true
                                    statusMessage = nil
                                    let success = await viewModel.extractMemoryFromCurrentChat()
                                    isExtracting = false
                                    if success {
                                        statusMessage = "✅ 会話から新しい記憶を抽出し、更新しました！"
                                    } else {
                                        statusMessage = "⚠️ 抽出できる新しい情報がありませんでした。"
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if isExtracting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isExtracting ? "抽出・分析中..." : "会話から記憶を更新")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.18))
                                .foregroundColor(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isExtracting || viewModel.messages.isEmpty)
                        }

                        if let msg = statusMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                    .padding(14)
                    .background(Color.purple.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )

                    // Memory Editor Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("📝 保存されている長期記憶（直接編集可能）")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if !viewModel.memoryNotes.isEmpty {
                                Button("全消去") {
                                    viewModel.memoryNotes = ""
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .buttonStyle(.plain)
                            }
                        }

                        TextEditor(text: $viewModel.memoryNotes)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 220)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )

                        Text("💡 ヒント: 「性格: 丁寧で結論から話す」「興味: Web開発・AIトレード」「静岡在住」のように手動で自由に書き足すこともできます。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Voice Command Cheat Sheet
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎙️ 音声コマンドで記憶を管理")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(alignment: .leading, spacing: 6) {
                            memoryCommandRow(command: "「今の会話を覚えておいて」", desc: "会話の重要事項や決定事項を要約して長期記憶に保存")
                            memoryCommandRow(command: "「私の性格や好みをメモして」", desc: "あなたの特徴や好みを抽出し記憶をアップデート")
                            memoryCommandRow(command: "「コンテキスト圧縮して」", desc: "過去のやりとりを要約してメモリに格納し、会話履歴を軽量化")
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(16)
            }
        }
        .frame(minWidth: 540, minHeight: 520)
    }

    private func memoryCommandRow(command: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(command)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)
            Text("→ \(desc)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}
