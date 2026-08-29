import SwiftUI

public struct ContextInspectorView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: InspectorTab = .structured
    @State private var isCopied: Bool = false

    public enum InspectorTab: String, CaseIterable, Identifiable {
        case structured = "📋 構造化ビュー"
        case rawJson = "{ } Raw JSON"

        public var id: String { rawValue }
    }

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    /// 現在の状態からLLMに送られるコンテキスト（メッセージ配列）を構築
    private var previewMessages: [ChatMessage] {
        var contextMessages: [ChatMessage] = []

        // 1. システムプロンプト
        let fullSystemPrompt = viewModel.buildIntegratedSystemPrompt()
        if !fullSystemPrompt.isEmpty {
            contextMessages.append(ChatMessage(role: .system, content: fullSystemPrompt))
        }

        // 2. 過去の会話履歴（上限スライス）
        let historyToKeep = max(2, viewModel.contextHistoryLimit * 2)
        let slicedHistory = Array(viewModel.messages.suffix(historyToKeep))
        contextMessages.append(contentsOf: slicedHistory)

        // 3. 現在入力中のメッセージ（もしあれば）
        let trimmedInput = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInput.isEmpty || !viewModel.attachedImages.isEmpty {
            let userMsg = ChatMessage(
                role: .user,
                content: trimmedInput.isEmpty ? "この画像について説明してください。" : trimmedInput,
                imageDataList: viewModel.attachedImages
            )
            contextMessages.append(userMsg)
        }

        return contextMessages
    }

    /// 合計文字数の計算
    private var totalCharacterCount: Int {
        previewMessages.reduce(0) { $0 + $1.content.count }
    }

    /// 推定トークン数 (日本語は約1.2〜1.4文字/トークン)
    private var estimatedTokenCount: Int {
        Int(Double(totalCharacterCount) * 1.3)
    }

    /// 送信されるJSON文字列
    private var rawJsonString: String {
        let payloadMessages = previewMessages.map { msg -> OllamaMessagePayload in
            let base64Images: [String]? = msg.imageDataList.isEmpty ? nil : msg.imageDataList.map { "[\($0.count) bytes image]" }
            return OllamaMessagePayload(role: msg.role.rawValue, content: msg.content, images: base64Images)
        }

        let request = OllamaChatRequest(
            model: viewModel.selectedModel,
            messages: payloadMessages,
            stream: true,
            think: viewModel.enableThinking
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(request),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView

            Divider()

            // Context Window Visual Gauge & Stats Bar
            contextGaugeBar

            Divider()

            // Main Content Area
            if selectedTab == .structured {
                structuredListView
            } else {
                rawJsonView
            }
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.accentColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("LLM コンテキスト インスペクター")
                    .font(.headline)
                Text("LLM（Ollama）へ実際に送信される直前のプロンプトとコンテキスト全容")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Button("閉じる (Esc)") {
                dismiss()
            }
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Context Window Visual Gauge Bar
    private var contextGaugeBar: some View {
        let usage = viewModel.contextUsagePercent
        let maxTokens = viewModel.maxContextWindowTokens
        let currentTokens = estimatedTokenCount

        return VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle.fill")
                        .foregroundColor(gaugeColor(for: usage))
                    Text("コンテキストウィンドウ使用率:")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(String(format: "%.1f", usage))%")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(gaugeColor(for: usage))
                }

                Spacer()

                HStack(spacing: 12) {
                    Text("推定 \(currentTokens.formatted()) / 最大 \(maxTokens.formatted()) tokens")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("(\(totalCharacterCount.formatted()) 文字)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Visual Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    // Fill Bar
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, gaugeColor(for: usage)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(min(1.0, usage / 100.0))), height: 8)
                }
            }
            .frame(height: 8)

            // Info tags
            HStack(spacing: 12) {
                Text("対象モデル: \(viewModel.selectedModel.isEmpty ? "未選択" : viewModel.selectedModel)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("メッセージ数: \(previewMessages.count) 件")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if viewModel.isRAGEnabled {
                    Text("📚 RAG自動検索: 有効")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }

                if viewModel.enableThinking {
                    Text("🧠 思考モード: ON")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }

                Spacer()

                if usage > 80 {
                    Text("⚠️ コンテキストが大きくなっています。「コンテキスト圧縮して」で要約整理できます")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }

    private func gaugeColor(for percent: Double) -> Color {
        if percent < 50 { return .green }
        if percent < 80 { return .blue }
        if percent < 90 { return .orange }
        return .red
    }

    // MARK: - Structured View
    private var structuredListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(Array(previewMessages.enumerated()), id: \.offset) { index, msg in
                    VStack(alignment: .leading, spacing: 6) {
                        // Role Header Badge
                        HStack(spacing: 6) {
                            Text("#\(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            roleBadge(for: msg.role)

                            Text("\(msg.content.count) 文字")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if !msg.imageDataList.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "photo")
                                    Text("\(msg.imageDataList.count) 枚の画像")
                                }
                                .font(.caption2)
                                .foregroundColor(.blue)
                            }

                            Spacer()
                        }

                        // Content Box
                        VStack(alignment: .leading, spacing: 6) {
                            Text(msg.content)
                                .font(.system(size: 13, design: msg.role == .system ? .monospaced : .default))
                                .textSelection(.enabled)
                                .lineSpacing(3)

                            // Attached Images Thumbnails
                            if !msg.imageDataList.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(msg.imageDataList.enumerated()), id: \.offset) { _, data in
                                            if let img = NSImage(data: data) {
                                                Image(nsImage: img)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 48, height: 48)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(backgroundColor(for: msg.role))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(borderColor(for: msg.role), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Raw JSON View
    private var rawJsonView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ollama API (`/api/chat`) POST リクエストボディ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyJsonToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "コピー完了" : "JSONをコピー")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))

            Divider()

            ScrollView {
                Text(rawJsonString)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func roleBadge(for role: MessageRole) -> some View {
        HStack(spacing: 4) {
            Image(systemName: roleIcon(for: role))
            Text(roleTitle(for: role))
                .fontWeight(.bold)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(roleColor(for: role).opacity(0.15))
        .foregroundColor(roleColor(for: role))
        .clipShape(Capsule())
    }

    private func roleTitle(for role: MessageRole) -> String {
        switch role {
        case .system: return "SYSTEM PROMPT"
        case .user: return "USER"
        case .assistant: return "ASSISTANT"
        }
    }

    private func roleIcon(for role: MessageRole) -> String {
        switch role {
        case .system: return "gearshape.fill"
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        }
    }

    private func roleColor(for role: MessageRole) -> Color {
        switch role {
        case .system: return .orange
        case .user: return .blue
        case .assistant: return .purple
        }
    }

    private func backgroundColor(for role: MessageRole) -> Color {
        switch role {
        case .system: return Color.orange.opacity(0.05)
        case .user: return Color.blue.opacity(0.04)
        case .assistant: return Color.purple.opacity(0.04)
        }
    }

    private func borderColor(for role: MessageRole) -> Color {
        switch role {
        case .system: return Color.orange.opacity(0.2)
        case .user: return Color.blue.opacity(0.2)
        case .assistant: return Color.purple.opacity(0.2)
        }
    }

    private func copyJsonToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(rawJsonString, forType: .string)
        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}
