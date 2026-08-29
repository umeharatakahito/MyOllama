import SwiftUI

public struct VoiceCommandsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "mic.badge.waveform")
                        .font(.title2)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎙️ 音声コマンド＆自動送信チートシート")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("マイクに向かって話しかけると、アプリが自動でコマンドを実行または送信します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content List
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 0. Claude特化タスクモード＆スラッシュコマンド
                    SectionCard(
                        icon: "sparkles.rectangle.stack.fill",
                        iconColor: .indigo,
                        title: "⚡ 特化タスクモード & スラッシュコマンド（Claude風）",
                        items: [
                            CommandItem(phrase: "/brainstorm または「ブレストモード」", desc: "💡 多角的視点・逆張り・異分野融合でアイデアを大量に発想・壁打ち"),
                            CommandItem(phrase: "/plan または「企画を作って」", desc: "🚀 課題/USP/機能要件/ビジネスモデル/ロードマップをプロ仕様で策定"),
                            CommandItem(phrase: "/paper または「論文モード」", desc: "📄 学術論文の構成・先行研究比較・仮説検証・アブストラクト作成"),
                            CommandItem(phrase: "/review または「レビューモード」", desc: "🔍 バグ・セキュリティ・可読性・設計の批判的レビューと改善Diff"),
                            CommandItem(phrase: "/code または「エキスパート実装」", desc: "💻 DRY/SOLID原則に基づく型安全で完成された本番品質コード生成"),
                            CommandItem(phrase: "/chat または「通常モード」", desc: "💬 フレンドリーで自然な日常対話・通常アシスタント")
                        ]
                    )

                    // 1. 特殊自動操作コマンド (App Actions)
                    SectionCard(
                        icon: "bolt.fill",
                        iconColor: .orange,
                        title: "🤖 アプリ自動操作コマンド（LLMを介さず即座に実行）",
                        items: [
                            CommandItem(phrase: "「チャットをリセットして」「会話を新しくして」", desc: "チャット履歴を消去して新しい対話を開始します"),
                            CommandItem(phrase: "「コンテキスト圧縮して」「会話をまとめて」", desc: "これまでの会話履歴を要約して長期メモリに保存し、履歴を軽量化します"),
                            CommandItem(phrase: "「ストップ」「静かにして」", desc: "ずんだもんの音声読み上げを即座に停止します"),
                            CommandItem(phrase: "「思考モードをオンにして / オフにして」", desc: "推論（think）モードを音声で切り替えます"),
                            CommandItem(phrase: "「RAGをオンにして / オフにして」", desc: "Obsidian知識ベース連携を音声で切り替えます")
                        ]
                    )

                    // 2. スマート自動送信トリガー（語尾検知で0.7秒送信）
                    SectionCard(
                        icon: "waveform.circle.fill",
                        iconColor: .purple,
                        title: "⚡ スマート自動送信トリガー（100+パターン語尾を検出して即送信）",
                        items: [
                            CommandItem(phrase: "〜どう？ / どう思う？ / どうかな？ / どうですか？", desc: "疑問や意見を求める語尾を検知して0.7秒後に自動送信"),
                            CommandItem(phrase: "〜教えて / 教えてください / 詳しく教えて", desc: "質問・教示を求める語尾を検知して自動送信"),
                            CommandItem(phrase: "〜作って / 直して / 調べて / まとめて / 翻訳して", desc: "タスク依頼・指示の語尾を検知して自動送信"),
                            CommandItem(phrase: "〜ですか？ / ますか？ / でしょうか？ / のかな？", desc: "敬語・丁寧な疑問形を検知して自動送信"),
                            CommandItem(phrase: "〜だよね？ / いい？ / 合ってる？ / 本当？", desc: "同意・確認を求める語尾を検知して自動送信"),
                            CommandItem(phrase: "〜なぜ？ / なんで？ / どういうこと？ / 理由は？", desc: "理由や詳細を尋ねる疑問詞を検知して自動送信")
                        ]
                    )

                    // 3. 常時ハンズフリーモードの使い方
                    SectionCard(
                        icon: "headphones",
                        iconColor: .blue,
                        title: "🎧 常時ハンズフリーモードの使い方",
                        items: [
                            CommandItem(phrase: "入力バーの「常時自動: ON」", desc: "クリックまたはメニューから常時自動をONにすると、マイクが常時待機します"),
                            CommandItem(phrase: "話しかけるだけで自動送信", desc: "質問を終えて少し間（0.7〜1.6秒）が空くと、自動でOllamaへ送信されます"),
                            CommandItem(phrase: "エコー自動防止", desc: "ずんだもんが回答を喋っている間はマイク認識が自動一時停止し、誤送信を防ぎます")
                        ]
                    )

                    // 4. 英語学習 & スニッピングショートカット (グローバル)
                    SectionCard(
                        icon: "character.book.closed.fill",
                        iconColor: .teal,
                        title: "📚 英語アシスタント & グローバルショートカット",
                        items: [
                            CommandItem(phrase: "Cmd + Shift + S", desc: "📸 画面範囲選択 OCR（マウスでドラッグした領域の英語を読み取って辞書＆発音HUDを表示）"),
                            CommandItem(phrase: "Cmd + Shift + E", desc: "🗣️ 選択テキスト英語解説（ブラウザや他アプリで選択中の英文を即座に解説）"),
                            CommandItem(phrase: "Cmd + C (コピー検知 / ダブルCmd+C)", desc: "🔤 英文コピー時に自動で辞書・発音HUDをポップアップ表示（省メモリ・即時表示）"),
                            CommandItem(phrase: "メニューバー常駐", desc: "🚀 ウィンドウを閉じてもメニューバーからワンクリックで呼び出し可能")
                        ]
                    )
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("閉じる (Esc)") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 540, minHeight: 520)
    }
}

private struct SectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [CommandItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.phrase)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Spacer()

                        Text(item.desc)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    if item.id != items.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct CommandItem: Identifiable {
    let id = UUID()
    let phrase: String
    let desc: String
}
