import SwiftUI
import AppKit

// MARK: - Transparent Floating Mascot Window Controller (Always on Top)
@MainActor
public final class FloatingMascotController: ObservableObject {
    public static let shared = FloatingMascotController()

    @Published public private(set) var isVisible: Bool = false
    private var panel: NSPanel?

    private init() {}

    public func show(viewModel: ChatViewModel) {
        if let existing = panel {
            existing.orderFrontRegardless()
            isVisible = true
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 280),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        // どんなアプリやフルスクリーン画面よりも確実に手前に配置
        newPanel.level = .statusBar
        newPanel.isMovableByWindowBackground = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.hidesOnDeactivate = false

        let contentView = FloatingMascotRootView(viewModel: viewModel) { [weak self] in
            self?.hide()
        }

        let hosting = NSHostingView(rootView: contentView)
        hosting.autoresizingMask = [.width, .height]
        newPanel.contentView = hosting

        // 画面右下に配置
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            newPanel.setFrameOrigin(
                NSPoint(x: visibleFrame.maxX - 240, y: visibleFrame.minY + 30)
            )
        }

        newPanel.orderFrontRegardless()
        self.panel = newPanel
        self.isVisible = true
    }

    public func hide() {
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }

    public func toggle(viewModel: ChatViewModel) {
        if isVisible {
            hide()
        } else {
            show(viewModel: viewModel)
        }
    }
}

// MARK: - Floating Mascot Root View (Borderless & Click-to-Activate)
struct FloatingMascotRootView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onClose: () -> Void
    @State private var isHovered: Bool = false
    @ObservedObject private var obsidianSync = ObsidianSyncService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // 3D Mascot Character (Click to activate MyOllama)
            Zundamon3DView(viewModel: viewModel, isFloatingWindow: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    activateMainWindow()
                }

            // Top Status Overlay (Close button, Obsidian sync status)
            VStack {
                HStack(spacing: 4) {
                    // Obsidian Sync Badge / Button
                    Button(action: {
                        _ = obsidianSync.syncLatestObsidianNote()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: obsidianSync.isSyncingWithObsidian ? "book.pages.fill" : "book.closed")
                                .font(.system(size: 9))
                                .foregroundColor(obsidianSync.isSyncingWithObsidian ? .cyan : .white)
                            Text(obsidianSync.activeNoteTitle ?? "Obsidian同期")
                                .font(.system(size: 9, weight: .bold))
                                .lineLimit(1)
                                .foregroundColor(.white)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(obsidianSync.isSyncingWithObsidian ? Color.cyan.opacity(0.75) : Color.black.opacity(0.55))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    // English Translation / Selection Button
                    Button(action: {
                        ScreenTextSelectionService.shared.triggerEnglishAssistant()
                    }) {
                        HStack(spacing: 2) {
                            Text("🔤")
                                .font(.system(size: 9))
                            Text("英語")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.75))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("画面上の英文をハイライトまたは範囲選択して即座に発音・直訳・文法解説（Cmd+Shift+E または ダブルCmd+C）")

                    Spacer()

                    if isHovered {
                        Button(action: activateMainWindow) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Circle().fill(Color.purple.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                        .help("MyOllamaを開く")

                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.65)))
                        }
                        .buttonStyle(.plain)
                        .help("フローティングを閉じる")
                    }
                }
                .padding(6)

                Spacer()

                // Bottom Mini Voice & Canvas HUD (話しかけた内容やステータスを表示)
                if viewModel.speechRecognizer.isRecording || !viewModel.inputText.isEmpty || viewModel.isGenerating {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isGenerating ? Color.purple : (viewModel.speechRecognizer.isRecording ? Color.red : Color.green))
                            .frame(width: 8, height: 8)

                        Text(viewModel.isGenerating ? "Obsidianノート更新中..." : (viewModel.inputText.isEmpty ? "聞き取り中..." : viewModel.inputText))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }

    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
        }
    }
}
