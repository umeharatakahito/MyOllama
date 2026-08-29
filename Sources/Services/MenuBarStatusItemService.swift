import SwiftUI
import AppKit

@MainActor
public final class MenuBarStatusItemService: NSObject {
    public static let shared = MenuBarStatusItemService()

    private var statusItem: NSStatusItem?
    private var clipboardMenuItem: NSMenuItem?

    override private init() {
        super.init()
    }

    public func setupMenuBar() {
        guard statusItem == nil else { return }

        // メニューバーに常駐アイテムを作成
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "MyOllama 英語アシスタント")
            button.imagePosition = .imageLeft
        }

        let menu = NSMenu()

        // 1. MyOllama を開く
        let openItem = NSMenuItem(title: "🚀 MyOllama を開く", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // 2. 範囲選択 OCR (Cmd+Shift+S)
        let snipItem = NSMenuItem(title: "📸 画面範囲選択 OCR", action: #selector(triggerSnip), keyEquivalent: "S")
        snipItem.keyEquivalentModifierMask = [.command, .shift]
        snipItem.target = self
        menu.addItem(snipItem)

        // 3. 選択テキスト翻訳 (Cmd+Shift+E)
        let translateItem = NSMenuItem(title: "🗣️ 選択テキスト英語解説", action: #selector(triggerAssistant), keyEquivalent: "E")
        translateItem.keyEquivalentModifierMask = [.command, .shift]
        translateItem.target = self
        menu.addItem(translateItem)

        menu.addItem(NSMenuItem.separator())

        // 4. クリップボード自動監視 トグル
        let isEnabled = ScreenTextSelectionService.shared.isAutoTranslateClipboardEnabled
        let clipItem = NSMenuItem(
            title: isEnabled ? "✅ 英語コピー自動検知: ON" : "⚪️ 英語コピー自動検知: OFF",
            action: #selector(toggleClipboardWatcher),
            keyEquivalent: ""
        )
        clipItem.target = self
        self.clipboardMenuItem = clipItem
        menu.addItem(clipItem)

        menu.addItem(NSMenuItem.separator())

        // 5. 終了
        let quitItem = NSMenuItem(title: "❌ MyOllama を終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    @objc private func triggerSnip() {
        ScreenTextSelectionService.shared.startScreenSnip()
    }

    @objc private func triggerAssistant() {
        ScreenTextSelectionService.shared.triggerEnglishAssistant()
    }

    @objc private func toggleClipboardWatcher() {
        let current = ScreenTextSelectionService.shared.isAutoTranslateClipboardEnabled
        let newSetting = !current
        ScreenTextSelectionService.shared.isAutoTranslateClipboardEnabled = newSetting
        clipboardMenuItem?.title = newSetting ? "✅ 英語コピー自動検知: ON" : "⚪️ 英語コピー自動検知: OFF"
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
