import SwiftUI

private struct ParsedContent {
    let thinking: String?
    let main: String
    let isThinkingInProgress: Bool
}

public struct MessageBubbleView: View {
    public let message: ChatMessage
    @State private var isHovered: Bool = false
    @State private var isCopied: Bool = false
    @State private var isThinkingExpanded: Bool = true
    @State private var isRagSourcesExpanded: Bool = false

    public init(message: ChatMessage) {
        self.message = message
    }

    private var parsedContent: ParsedContent {
        let raw = message.content
        guard let startRange = raw.range(of: "<think>") else {
            return ParsedContent(thinking: nil, main: raw, isThinkingInProgress: false)
        }

        if let endRange = raw.range(of: "</think>") {
            let thinkText = String(raw[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let mainText = String(raw[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedContent(thinking: thinkText, main: mainText, isThinkingInProgress: false)
        } else {
            // </think> がまだ閉じていない場合（ストリーミング思考中）
            let thinkText = String(raw[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedContent(thinking: thinkText, main: "", isThinkingInProgress: true)
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Sender label & timestamp
                HStack(spacing: 6) {
                    Text(message.role == .user ? "あなた" : "Ollama")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }

                // Message Body
                let parsed = parsedContent
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Attached Images
                        if !message.imageDataList.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(Array(message.imageDataList.enumerated()), id: \.offset) { _, data in
                                    if let nsImage = NSImage(data: data) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: 220, maxHeight: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.bottom, parsed.main.isEmpty ? 0 : 2)
                        }

                        if message.content.isEmpty && message.isStreaming {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("考え中...")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            // Thinking process block (if any)
                            if let thinking = parsed.thinking, !thinking.isEmpty || parsed.isThinkingInProgress {
                                DisclosureGroup(
                                    isExpanded: $isThinkingExpanded,
                                    content: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if !thinking.isEmpty {
                                                Text(thinking)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                    .textSelection(.enabled)
                                            }
                                            if parsed.isThinkingInProgress {
                                                HStack(spacing: 4) {
                                                    ProgressView()
                                                        .controlSize(.mini)
                                                    Text("思考中...")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.top, 2)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color.primary.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    },
                                    label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "brain.head.profile")
                                                .foregroundColor(.purple)
                                            Text(parsed.isThinkingInProgress ? "思考中..." : "思考プロセス")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                )
                                .padding(.bottom, parsed.main.isEmpty ? 0 : 4)
                            }

                            // Main message content
                            if !parsed.main.isEmpty {
                                Text(LocalizedStringKey(parsed.main))
                                    .textSelection(.enabled)
                                    .font(.system(size: 14, weight: .regular))
                                    .lineSpacing(4)
                            }

                            // Referenced Web / Weather Sources (if any)
                            if !message.referencedWebSources.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(message.referencedWebSources) { hit in
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 4) {
                                                Image(systemName: hit.title.contains("天気") ? "cloud.sun.fill" : "globe")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("🌐 \(hit.title)")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.blue)
                                            }
                                            Text(hit.snippet)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .lineLimit(4)
                                        }
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.blue.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    }
                                }
                                .padding(.top, 4)
                            }

                            // Referenced RAG Sources (if any)
                            if !message.referencedRagSources.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    DisclosureGroup(
                                        isExpanded: $isRagSourcesExpanded,
                                        content: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                ForEach(message.referencedRagSources) { hit in
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "doc.text.fill")
                                                                .font(.caption2)
                                                                .foregroundColor(.cyan)
                                                            Text(hit.title)
                                                                .font(.system(size: 12, weight: .semibold))
                                                                .foregroundColor(.primary)
                                                        }
                                                        Text(hit.content.prefix(200))
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(3)
                                                    }
                                                    .padding(6)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.cyan.opacity(0.06))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                }
                                            }
                                            .padding(.top, 4)
                                        },
                                        label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "book.pages.fill")
                                                    .foregroundColor(.cyan)
                                                Text("📚 参照ナレッジ (\(message.referencedRagSources.count) 件のノート)")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.cyan)
                                            }
                                        }
                                    )
                                }
                                .padding(.top, 6)
                            }
                        }

                        if message.isStreaming && !message.content.isEmpty && !parsed.isThinkingInProgress {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.8)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundColor(bubbleTextColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Actions on hover
                if isHovered && !message.content.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: copyToClipboard) {
                            HStack(spacing: 4) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                Text(isCopied ? "コピー完了" : "コピー")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        if message.role == .assistant {
                            Button(action: {
                                if VoicevoxService.shared.isSpeaking {
                                    VoicevoxService.shared.stop()
                                } else {
                                    VoicevoxService.shared.speak(text: message.content)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: VoicevoxService.shared.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                    Text(VoicevoxService.shared.isSpeaking ? "停止" : "読み上げ")
                                }
                                .font(.caption2)
                                .foregroundColor(VoicevoxService.shared.isSpeaking ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
            }

            if message.role == .user {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 2)
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var bubbleBackground: some View {
        Group {
            if message.role == .user {
                Color.accentColor
            } else {
                Color(nsColor: .controlBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private var bubbleTextColor: Color {
        if message.role == .user {
            return .white
        } else {
            return .primary
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let parsed = parsedContent
        let textToCopy = parsed.main.isEmpty ? message.content : parsed.main
        pasteboard.setString(textToCopy, forType: .string)
        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

// Simple horizontal/wrapping layout for attached thumbnails
private struct FlowLayout: View {
    var spacing: CGFloat = 8
    var content: [AnyView]

    init<Views: View>(spacing: CGFloat = 8, @ViewBuilder content: () -> Views) {
        self.spacing = spacing
        self.content = [AnyView(content())]
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<content.count, id: \.self) { index in
                content[index]
            }
        }
    }
}
