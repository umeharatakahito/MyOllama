import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // メニューバー（ステータスバー）アイコンの常駐設定
        MenuBarStatusItemService.shared.setupMenuBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // メインウィンドウが閉じられてもアプリは終了せず、バックグラウンド常駐（メニューバー）で待機
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Dockアイコンがクリックされた時にウィンドウを再表示
            for window in sender.windows where !(window is NSPanel) && window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 終了時にすべてのオーディオ・マイク・フローティングウィンドウを完全クリーンアップ
        SpeechRecognitionService.shared.stopRecording()
        VoicevoxService.shared.stop()
        FloatingMascotController.shared.hide()
    }
}

@main
struct MyOllamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .navigationTitle("MyOllama")
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 800, height: 600)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "myollama" else { return }

        // myollama://sync-note?path=...
        if url.host == "sync-note" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let path = components?.queryItems?.first(where: { $0.name == "path" })?.value {
                let noteURL = URL(fileURLWithPath: path)
                let title = noteURL.deletingPathExtension().lastPathComponent
                ObsidianSyncService.shared.setTargetNote(url: noteURL, title: title)

                viewModel.selectedTaskMode = TaskCommandMode.allModes.first(where: { $0.id == "brainstorm" }) ?? viewModel.selectedTaskMode
                viewModel.isVoicevoxEnabled = true
                if !viewModel.speechRecognizer.isAlwaysListening {
                    viewModel.toggleAlwaysListening()
                }
                FloatingMascotController.shared.show(viewModel: viewModel)

                let reply = "Obsidianで開いているノート「\(title).md」を読み込んだのだ！何でも聞いてほしいのだ！🌱✨"
                viewModel.messages.append(ChatMessage(role: .assistant, content: reply))
                if viewModel.voicevox.isAvailable {
                    viewModel.speakMessage(reply)
                }
            }
        } else if url.host == "start-call" {
            viewModel.toggleRealtimeVoiceCall()
        }
    }
}
