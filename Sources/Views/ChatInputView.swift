import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Native macOS Chat Text View with IME, Shortcut & Paste Support
public struct AutoGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onPasteImages: (([Data]) -> Void)?

    public init(
        text: Binding<String>,
        onCommit: @escaping () -> Void,
        onPasteImages: (([Data]) -> Void)? = nil
    ) {
        self._text = text
        self.onCommit = onCommit
        self.onPasteImages = onPasteImages
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = CustomNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 6)

        textView.onCommit = onCommit
        textView.onPasteImages = onPasteImages

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomNSTextView else { return }

        if textView.string != text {
            textView.string = text
        }
        textView.onCommit = onCommit
        textView.onPasteImages = onPasteImages
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoGrowingTextView
        weak var textView: CustomNSTextView?

        init(_ parent: AutoGrowingTextView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

// MARK: - Subclassed NSTextView for Custom Key Handling & Universal Image Paste
class CustomNSTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onPasteImages: (([Data]) -> Void)?

    override func doCommand(by selector: Selector) {
        // 通常の改行コマンド (Enterキー)
        if selector == #selector(insertNewline(_:)) {
            // Shiftキーが押されている場合は改行を挿入
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                insertNewlineIgnoringFieldEditor(nil)
                return
            }

            // IME変換中でなく、通常のEnterなら送信
            onCommit?()
            return
        }

        // ペーストコマンドの横取り
        if selector == #selector(paste(_:)) || selector == #selector(pasteAsPlainText(_:)) {
            if handleImagePaste() {
                return
            }
        }

        super.doCommand(by: selector)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd + V のキーイベントを直接検知
        if event.type == .keyDown && event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "v" || event.keyCode == 9 {
                if handleImagePaste() {
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        if handleImagePaste() {
            return
        }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if handleImagePaste() {
            return
        }
        super.pasteAsPlainText(sender)
    }

    private func handleImagePaste() -> Bool {
        let pasteboard = NSPasteboard.general
        let images = PasteboardHelper.extractImages(from: pasteboard)
        if !images.isEmpty {
            onPasteImages?(images)
            return true
        }
        return false
    }
}

// MARK: - Universal Pasteboard Image Extractor
public enum PasteboardHelper {
    public static func extractImages(from pasteboard: NSPasteboard) -> [Data] {
        var result: [Data] = []

        // 1. NSImage クラスとしての直接読み込み（スクショ等で最も確実）
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            for img in images {
                if let data = img.resizedData() {
                    result.append(data)
                }
            }
        }

        if !result.isEmpty {
            return result
        }

        // 2. TIFF / PNG / JPEG 直接データ取得
        let types: [NSPasteboard.PasteboardType] = [
            .tiff,
            .png,
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.tiff"),
            NSPasteboard.PasteboardType("public.jpeg")
        ]
        for type in types {
            if let data = pasteboard.data(forType: type),
               let img = NSImage(data: data),
               let resized = img.resizedData() {
                result.append(resized)
                return result
            }
        }

        // 3. Finder などでファイルとしてコピーされた画像
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "webp", "gif", "heic", "tiff", "bmp"].contains(ext) {
                    if let image = NSImage(contentsOf: url),
                       let data = image.resizedData() {
                        result.append(data)
                    } else if let rawData = try? Data(contentsOf: url) {
                        result.append(rawData)
                    }
                }
            }
        }

        return result
    }
}

// MARK: - ChatInputView
public struct ChatInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var speechRecognizer = SpeechRecognitionService.shared
    @ObservedObject private var voicevox = VoicevoxService.shared
    var onInspectContext: (() -> Void)?
    var onOpenRAG: (() -> Void)?
    var onOpenVoiceHelp: (() -> Void)?
    @State private var isTargetedForDrop: Bool = false

    public init(
        viewModel: ChatViewModel,
        onInspectContext: (() -> Void)? = nil,
        onOpenRAG: (() -> Void)? = nil,
        onOpenVoiceHelp: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onInspectContext = onInspectContext
        self.onOpenRAG = onOpenRAG
        self.onOpenVoiceHelp = onOpenVoiceHelp
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Attached Images Preview Strip (if any)
            if !viewModel.attachedImages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(viewModel.attachedImages.enumerated()), id: \.offset) { index, data in
                                ZStack(alignment: .topTrailing) {
                                    if let nsImage = NSImage(data: data) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                            )
                                    }

                                    Button(action: {
                                        withAnimation {
                                            viewModel.removeAttachedImage(at: index)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.7)))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }

                    // Warning if current model does not support Vision
                    if !viewModel.isCurrentModelVisionSupported {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("現在のモデル「\(viewModel.selectedModel)」は画像入力（Vision）に対応していません")
                                .font(.caption)
                                .foregroundColor(.primary)

                            if let visionModel = viewModel.availableVisionModels.first {
                                Button("👁️ \(visionModel.name) に切替") {
                                    withAnimation {
                                        viewModel.selectedModel = visionModel.name
                                    }
                                }
                                .font(.caption2)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            // Active Mode Banner (if not normal)
            if viewModel.selectedTaskMode.id != "normal" {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.selectedTaskMode.icon)
                        .foregroundColor(.indigo)
                        .font(.caption)
                    Text("【\(viewModel.selectedTaskMode.name)モード】")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                    Text(viewModel.selectedTaskMode.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("通常に戻す") {
                        withAnimation {
                            viewModel.selectedTaskMode = TaskCommandMode.defaultMode
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                )
            }

            // Action Buttons Bar (Horizontal Scrollable with Single Line Protection)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    // 🌟 BIG HERO: リアルタイム音声対話ワンクリック起動/停止ボタン
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.toggleRealtimeVoiceCall()
                        }
                    }) {
                        HStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(speechRecognizer.isAlwaysListening ? Color.red : Color.green)
                                    .frame(width: 14, height: 14)
                                Image(systemName: speechRecognizer.isAlwaysListening ? "waveform" : "mic.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text(speechRecognizer.isAlwaysListening ? "通話中 (停止)" : "🎙️ リアルタイム通話")
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)

                            if speechRecognizer.isAlwaysListening {
                                Text("●")
                                    .font(.system(size: 8))
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(
                            speechRecognizer.isAlwaysListening
                            ? LinearGradient(colors: [Color.purple.opacity(0.35), Color.red.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.green.opacity(0.28), Color.purple.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(speechRecognizer.isAlwaysListening ? .purple : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(speechRecognizer.isAlwaysListening ? Color.purple : Color.green.opacity(0.6), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("ワンクリックで「常時ハンズフリー認識 ＋ 3Dずんだもん召喚 ＋ 音声読み上げ」を一発起動します")

                    // 📝 Obsidian 新規白紙ノートを開いて壁打ち
                    Button(action: {
                        withAnimation {
                            viewModel.openBlankObsidianNoteAndStartCall()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.system(size: 11))
                                .foregroundColor(.cyan)
                            Text("📝 Obsidian白紙")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Obsidianアプリを起動して真っ白な新規ノートを開き、フローティングずんだもんと即座に音声壁打ちを開始します")

                    // Task Command Mode Selector Menu (Claude-style)
                    Menu {
                        ForEach(TaskCommandMode.allModes) { mode in
                            Button(action: {
                                withAnimation {
                                    viewModel.selectedTaskMode = mode
                                    if mode.autoEnableThinking {
                                        viewModel.enableThinking = true
                                    }
                                }
                            }) {
                                HStack {
                                    Label("\(mode.name) (\(mode.slashCommand))", systemImage: mode.icon)
                                    if viewModel.selectedTaskMode.id == mode.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.selectedTaskMode.icon)
                                .font(.system(size: 11))
                            Text(viewModel.selectedTaskMode.id == "normal" ? "モード" : viewModel.selectedTaskMode.name)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(viewModel.selectedTaskMode.id != "normal" ? Color.indigo.opacity(0.25) : Color.primary.opacity(0.06))
                        .foregroundColor(viewModel.selectedTaskMode.id != "normal" ? .indigo : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(viewModel.selectedTaskMode.id != "normal" ? Color.indigo.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("ブレスト、企画書作成、論文立案、コードレビューなど、Claudeのように特化モードを選択")

                    // Zundamon TTS & Speed Selector
                    HStack(spacing: 2) {
                        Button(action: {
                            withAnimation {
                                viewModel.isVoicevoxEnabled.toggle()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: viewModel.isVoicevoxEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                                    .font(.system(size: 11))
                                Text("ずんだもん: \(viewModel.isVoicevoxEnabled ? "ON" : "OFF")")
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(height: 26)
                            .background(viewModel.isVoicevoxEnabled ? Color.green.opacity(0.2) : Color.primary.opacity(0.06))
                            .foregroundColor(viewModel.isVoicevoxEnabled ? Color.green : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("VOICEVOXによるずんだもんリアルタイム音声読み上げをON/OFFします")

                        if viewModel.isVoicevoxEnabled {
                            Menu {
                                ForEach([0.8, 1.0, 1.15, 1.3, 1.5, 1.7, 2.0], id: \.self) { speed in
                                    Button("\(String(format: "%.2fx", speed))\(speed == 1.15 ? " (おすすめ)" : "")") {
                                        viewModel.voiceSpeedScale = speed
                                    }
                                }
                            } label: {
                                Text("\(String(format: "%.2fx", viewModel.voiceSpeedScale))")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .frame(height: 26)
                                    .background(Color.green.opacity(0.12))
                                    .foregroundColor(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help("ずんだもんの話速（スピード）を変更")
                        }
                    }
                    .fixedSize()

                    // Web Search Toggle Button
                    Button(action: {
                        withAnimation {
                            viewModel.isWebSearchEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isWebSearchEnabled ? "globe.asia.australia.fill" : "globe")
                                .font(.system(size: 11))
                            Text("Web: \(viewModel.isWebSearchEnabled ? "ON" : "OFF")")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(viewModel.isWebSearchEnabled ? Color.blue.opacity(0.18) : Color.primary.opacity(0.06))
                        .foregroundColor(viewModel.isWebSearchEnabled ? Color.blue : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("天気予報や最新情報のWeb検索を自動実行して回答に活用します")

                    // RAG Toggle Button
                    Button(action: {
                        withAnimation {
                            viewModel.isRAGEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isRAGEnabled ? "book.pages.fill" : "book.closed")
                                .font(.system(size: 11))
                            Text("RAG: \(viewModel.isRAGEnabled ? "ON" : "OFF")")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(viewModel.isRAGEnabled ? Color.cyan.opacity(0.2) : Color.primary.opacity(0.06))
                        .foregroundColor(viewModel.isRAGEnabled ? Color.cyan : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Open Notebook (Obsidian) の知識ベースを自動検索して回答に活用します")

                    // Attach Image Button
                    Button(action: openImagePicker) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 11))
                            Text("画像")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("画像ファイルを選択して添付 (Cmd+Vでスクショ貼付も可能)")

                    // Thinking Mode Toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.enableThinking.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.enableThinking ? "brain.head.profile.fill" : "brain.head.profile")
                                .font(.system(size: 11))
                            Text("思考: \(viewModel.enableThinking ? "ON" : "OFF")")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(viewModel.enableThinking ? Color.purple.opacity(0.18) : Color.primary.opacity(0.06))
                        .foregroundColor(viewModel.enableThinking ? .purple : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Ollama APIに think フラグを送信します")

                    // English Text Selection (OCR / Direct Highlight) Button
                    Button(action: {
                        ScreenTextSelectionService.shared.triggerEnglishAssistant()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.system(size: 11))
                            Text("🔤 英語解説")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(height: 26)
                        .background(Color.cyan.opacity(0.18))
                        .foregroundColor(.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("画面上の英文をマウスで選択して即座に発音・直訳・文法解説（Cmd+Shift+E）")

                    // Context Inspector & Visual Usage Gauge
                    if let onInspect = onInspectContext {
                        Button(action: onInspect) {
                            HStack(spacing: 4) {
                                Image(systemName: "gauge.with.needle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(viewModel.contextUsagePercent > 80 ? .orange : .blue)
                                Text("\(String(format: "%.0f", viewModel.contextUsagePercent))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(viewModel.contextUsagePercent > 80 ? .orange : .primary)
                                    .lineLimit(1)
                                Text("コンテキスト")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(height: 26)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("コンテキスト使用率: \(String(format: "%.1f", viewModel.contextUsagePercent))% (約 \(viewModel.estimatedCurrentTokens) / \(viewModel.maxContextWindowTokens) tokens)")
                    }
                }
                .frame(height: 28)
                .padding(.horizontal, 2)
            }
            .frame(height: 30)

            // Slash Command Inline Suggestions (Claude-style)
            if viewModel.inputText.hasPrefix("/") && !viewModel.inputText.contains(" ") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(TaskCommandMode.allModes.filter { $0.id != "normal" }) { mode in
                            Button(action: {
                                withAnimation {
                                    viewModel.selectedTaskMode = mode
                                    viewModel.inputText = "\(mode.slashCommand) "
                                    if mode.autoEnableThinking {
                                        viewModel.enableThinking = true
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 11))
                                    Text(mode.slashCommand)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    Text(mode.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.indigo.opacity(0.15))
                                .foregroundColor(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Input Box & Action Buttons
            HStack(alignment: .bottom, spacing: 10) {
                // Native Text View with SwiftUI Overlay Placeholder
                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty {
                        Text(placeholderText)
                            .font(.system(size: 14))
                            .foregroundColor(speechRecognizer.isRecording ? Color.red.opacity(0.8) : .secondary.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }

                    AutoGrowingTextView(
                        text: $viewModel.inputText,
                        onCommit: {
                            if canSend {
                                viewModel.sendMessage()
                            }
                        },
                        onPasteImages: { imageDatas in
                            withAnimation {
                                viewModel.attachImages(imageDatas)
                            }
                        }
                    )
                    .frame(minHeight: 34, maxHeight: 140)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(speechRecognizer.isRecording ? Color.red : (isTargetedForDrop ? Color.accentColor : Color.primary.opacity(0.15)), lineWidth: speechRecognizer.isRecording || isTargetedForDrop ? 2 : 1)
                )
                .onDrop(of: [.fileURL, .image], isTargeted: $isTargetedForDrop) { providers in
                    handleDrop(providers: providers)
                }

                // Send or Stop Button
                if viewModel.isGenerating {
                    Button(action: { viewModel.stopGenerating() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("応答の生成を停止")
                } else {
                    Button(action: { viewModel.sendMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(canSend ? Color.accentColor : Color.secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .help("送信 (Enter)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var placeholderText: String {
        if speechRecognizer.isAlwaysListening {
            if SmartVoiceTrigger.matchesTriggerPattern(viewModel.inputText) {
                return "⚡ 質問・依頼を検知！まもなく自動送信します..."
            }
            return "🎧 常時リスニング中... 声をかけると質問や間を検知して自動送信します"
        }
        if speechRecognizer.isRecording {
            return "🎙️ 音声を認識中... 話し終わったらマイクボタンを押してください"
        }
        if !viewModel.attachedImages.isEmpty {
            return "画像についての質問を入力... (Enterで送信)"
        }
        return "メッセージを入力... (Enterで送信, Shift+Enterで改行, Cmd+Vで画像ペースト)"
    }

    private var canSend: Bool {
        (!viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.attachedImages.isEmpty) &&
        !viewModel.isGenerating &&
        viewModel.isConnected &&
        !viewModel.selectedModel.isEmpty
    }

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .gif, .webP, .heic]

        if panel.runModal() == .OK {
            viewModel.attachImages(from: panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            viewModel.attachImage(data: data)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            viewModel.attachImages(from: [url])
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            viewModel.attachImages(from: [url])
                        }
                    }
                }
            }
        }
        return true
    }
}
