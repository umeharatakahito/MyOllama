import SwiftUI
import AppKit

@MainActor
public final class EnglishHUDOverlayController: ObservableObject {
    public static let shared = EnglishHUDOverlayController()

    @Published public var currentText: String = ""
    @Published public var currentDefinition: DictionaryDefinition? = nil
    @Published public var isVisible: Bool = false

    private var hudWindow: NSPanel?

    private init() {}

    public func showHUD(text: String, at point: CGPoint? = nil) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        self.currentText = clean

        // 1. macOS 内蔵辞書から意味を即座に高速検索（0.01秒・メモリ0MB）
        self.currentDefinition = DictionaryLookupService.shared.lookup(text: clean)

        // 2. ネイティブ発音を即座に再生
        EnglishLearningService.shared.speakNativeEnglish(text: clean)

        if hudWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 230),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let rootView = EnglishHUDPopupView(controller: self) {
                self.hideHUD()
            }
            panel.contentView = NSHostingView(rootView: rootView)
            self.hudWindow = panel
        }

        if let panel = hudWindow {
            // 位置調整（指定座標またはマウスカーソル付近）
            let mouseLoc = point ?? NSEvent.mouseLocation
            let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let x = min(max(mouseLoc.x - 190, 20), screen.width - 400)
            let y = min(max(mouseLoc.y - 230, 40), screen.height - 250)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.orderFrontRegardless()
            self.isVisible = true
        }
    }

    public func hideHUD() {
        hudWindow?.orderOut(nil)
        self.isVisible = false
        EnglishLearningService.shared.stopSpeaking()
    }
}

// MARK: - 🪟 English HUD Popup View (Glassmorphism + Instant Dictionary)

public struct EnglishHUDPopupView: View {
    @ObservedObject var controller: EnglishHUDOverlayController
    @ObservedObject var learningService = EnglishLearningService.shared
    let onClose: () -> Void

    @State private var isAddedToVocab: Bool = false

    private var displayMeaning: String {
        if let def = controller.currentDefinition, !def.meanings.isEmpty {
            return def.meanings.joined(separator: " / ")
        }
        return "選択した単語 / フレーズ"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Top Bar (Pronunciation & Close)
            HStack(spacing: 8) {
                Image(systemName: "character.book.closed.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 14))

                Text("英語アシスタント")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                // Voice Selector Menu
                Menu {
                    Button("Samantha (米語・女性 🇺🇸)") {
                        learningService.selectedEnglishVoiceName = "Samantha"
                        learningService.speakNativeEnglish(text: controller.currentText)
                    }
                    Button("Daniel (イギリス英語・男性 🇬🇧)") {
                        learningService.selectedEnglishVoiceName = "Daniel"
                        learningService.speakNativeEnglish(text: controller.currentText)
                    }
                    Button("Karen (オーストラリア英語・女性 🇦🇺)") {
                        learningService.selectedEnglishVoiceName = "Karen"
                        learningService.speakNativeEnglish(text: controller.currentText)
                    }
                } label: {
                    Text(learningService.selectedEnglishVoiceName == "Samantha" ? "🇺🇸 Samantha" : (learningService.selectedEnglishVoiceName == "Daniel" ? "🇬🇧 Daniel" : "🇦🇺 Karen"))
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Native Pronunciation Button
                Button(action: {
                    learningService.speakNativeEnglish(text: controller.currentText)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: learningService.isSpeakingNative ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .foregroundColor(.white)
                        Text("発音")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("ネイティブ英語音声を再生")

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // 2. Selected English Text & Phonetic
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(controller.currentText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(3)

                    if let def = controller.currentDefinition, !def.phonetic.isEmpty {
                        Text(def.phonetic)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    if let def = controller.currentDefinition, !def.partOfSpeech.isEmpty {
                        Text("[\(def.partOfSpeech)]")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }

            // 3. Instant Dictionary / Translation Box (0MB Memory)
            if let def = controller.currentDefinition, !def.meanings.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(def.meanings.prefix(2).enumerated()), id: \.offset) { _, meaning in
                        HStack(alignment: .top, spacing: 4) {
                            Text("・")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11, weight: .bold))
                            Text(meaning)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(8)
            }

            Divider()

            // 4. Action Buttons Bar
            HStack(spacing: 8) {
                // Add to Vocabulary Button
                Button(action: {
                    let def = controller.currentDefinition
                    learningService.addVocabularyItem(
                        word: controller.currentText,
                        phonetic: def?.phonetic ?? "",
                        partOfSpeech: def?.partOfSpeech ?? "",
                        meaning: displayMeaning,
                        exampleSentence: controller.currentText
                    )
                    isAddedToVocab = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isAddedToVocab ? "checkmark.circle.fill" : "bookmark.fill")
                        Text(isAddedToVocab ? "単語帳に追加済" : "単語帳に追加")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAddedToVocab ? Color.green.opacity(0.2) : Color.primary.opacity(0.08))
                    .foregroundColor(isAddedToVocab ? .green : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()

                // Ask Chat for Grammar & Detailed Analysis (Ollama)
                Button(action: {
                    onClose()
                    NotificationCenter.default.post(
                        name: Notification.Name("MyOllama.RequestEnglishAnalysis"),
                        object: controller.currentText
                    )
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble.fill")
                        Text("💬 文法・詳細解説")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("MyOllamaのチャットで直訳・意訳・文法構造・単語リストを展開して解説します")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
        )
        .frame(width: 380)
    }
}
