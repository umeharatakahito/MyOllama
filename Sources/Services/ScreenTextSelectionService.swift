import Foundation
import AppKit
import Vision
import SwiftUI

@MainActor
public final class ScreenTextSelectionService: ObservableObject {
    public static let shared = ScreenTextSelectionService()

    @Published public var isSnapping: Bool = false
    @Published public var lastRecognizedText: String = ""

    private var snipWindow: NSWindow?

    @Published public var isAutoTranslateClipboardEnabled: Bool = true
    private var lastObservedPasteboardCount: Int = NSPasteboard.general.changeCount

    private init() {
        setupGlobalShortcut()
        _ = CarbonHotKeyService.shared
        startClipboardWatcher()
    }

    /// クリップボードの変化を監視して英文コピー時に自動で英語HUDを表示
    private func startClipboardWatcher() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isAutoTranslateClipboardEnabled else { return }
                let currentCount = NSPasteboard.general.changeCount
                if currentCount != self.lastObservedPasteboardCount {
                    self.lastObservedPasteboardCount = currentCount
                    if let copied = NSPasteboard.general.string(forType: .string) {
                        let trimmed = copied.trimmingCharacters(in: .whitespacesAndNewlines)
                        // 英字が含まれており、2〜800文字の英文/単語であれば自動ポップアップ
                        if trimmed.count >= 2 && trimmed.count <= 800 && self.containsEnglishWords(trimmed) {
                            EnglishHUDOverlayController.shared.showHUD(text: trimmed)
                        }
                    }
                }
            }
        }
    }

    private func containsEnglishWords(_ text: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "[a-zA-Z]{2,}")
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex?.firstMatch(in: text, options: [], range: range) != nil
    }

    private var lastCopyTimestamp: Date = Date.distantPast

    // MARK: - ⌨️ グローバルキーボードショートカット (他アプリ前面時でも反応)
    private func setupGlobalShortcut() {
        // 1. MyOllamaがアクティブな時のローカルモニター
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd + Shift + S : 画面範囲選択スニッピング OCR
            if event.modifierFlags.contains([.command, .shift]) && (event.charactersIgnoringModifiers?.lowercased() == "s" || event.keyCode == 1) {
                Task { @MainActor [weak self] in
                    self?.startScreenSnip()
                }
                return nil
            }

            // Cmd + Shift + E : 選択テキスト翻訳（無ければスニップ）
            if event.modifierFlags.contains([.command, .shift]) && (event.charactersIgnoringModifiers?.lowercased() == "e" || event.keyCode == 14) {
                Task { @MainActor [weak self] in
                    self?.triggerEnglishAssistant()
                }
                return nil
            }
            return event
        }

        // 2. ブラウザや他アプリがアクティブな時のグローバルモニター
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd + Shift + S : 画面範囲選択スニッピング OCR
            if event.modifierFlags.contains([.command, .shift]) && (event.charactersIgnoringModifiers?.lowercased() == "s" || event.keyCode == 1) {
                Task { @MainActor [weak self] in
                    self?.startScreenSnip()
                }
                return
            }

            // Cmd + Shift + E : 選択テキスト翻訳
            if event.modifierFlags.contains([.command, .shift]) && (event.charactersIgnoringModifiers?.lowercased() == "e" || event.keyCode == 14) {
                Task { @MainActor [weak self] in
                    self?.triggerEnglishAssistant()
                }
                return
            }

            // 💡 ダブル Cmd+C 検知 (0.4秒以内に2回 Cmd+C を押したら英語解説HUDを自動起動)
            if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers?.lowercased() == "c" || event.keyCode == 8) {
                let now = Date()
                if let last = self?.lastCopyTimestamp, now.timeIntervalSince(last) < 0.4 {
                    self?.lastCopyTimestamp = Date.distantPast
                    Task { @MainActor in
                        // クリップボードから即座に取得して表示
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        if let text = NSPasteboard.general.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            EnglishHUDOverlayController.shared.showHUD(text: text.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                } else {
                    self?.lastCopyTimestamp = now
                }
            }
        }
    }

    // MARK: - 🎯 統合トリガー: テキストハイライト選択を最優先、無ければ範囲選択OCR
    public func triggerEnglishAssistant() {
        Task {
            // 1. まずアクティブアプリでハイライト選択中のテキストがあるか取得を試みる
            if let selectedText = await getSelectedTextFromActiveApp(), !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.lastRecognizedText = trimmed
                EnglishHUDOverlayController.shared.showHUD(text: trimmed)
                return
            }

            // 2. 選択テキストが無ければ、画面矩形スニッピング（範囲選択OCR）モードを起動
            self.startScreenSnip()
        }
    }

    // MARK: - 📄 アクティブアプリからの選択テキスト自動取得 (Accessibility & Clipboard Fallback)
    public func getSelectedTextFromActiveApp() async -> String? {
        // A. Accessibility API 経由での取得
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        if result == .success, let element = focusedElement {
            var selectedTextValue: AnyObject?
            let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
            if textResult == .success, let str = selectedTextValue as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return str
            }
        }

        // B. クリップボード自動取得（Cmd+C シミュレーション）
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        // Cmd+C キーイベントを送信
        let src = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true) // Command Key
        let cDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)   // 'C' Key
        let cUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)

        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)

        // クリップボードの更新を最大 150ms 待機
        for _ in 0..<3 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if pasteboard.changeCount != previousChangeCount {
                if let copied = pasteboard.string(forType: .string), !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return copied
                }
            }
        }

        return nil
    }

    // MARK: - 📸 画面スニッピング（範囲選択 OCR）の開始

    public func startScreenSnip(onRecognized: (@Sendable (String, CGPoint) -> Void)? = nil) {
        guard !isSnapping else { return }
        isSnapping = true

        guard let screen = NSScreen.main else {
            isSnapping = false
            return
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        let snipView = ScreenSnipOverlayView(screenFrame: screen.frame) { [weak self] selectedRect in
            Task { @MainActor [weak self] in
                self?.closeSnipWindow()
                if let rect = selectedRect, rect.width > 5, rect.height > 5 {
                    await self?.captureAndRecognizeText(in: rect, screen: screen, completion: onRecognized)
                } else {
                    self?.isSnapping = false
                }
            }
        }

        window.contentView = NSHostingView(rootView: snipView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.snipWindow = window
    }

    public func closeSnipWindow() {
        snipWindow?.orderOut(nil)
        snipWindow = nil
        isSnapping = false
    }

    // MARK: - 🔍 画面キャプチャ & Apple Vision OCR テキスト認識

    private func captureAndRecognizeText(
        in rect: CGRect,
        screen: NSScreen,
        completion: (@Sendable (String, CGPoint) -> Void)?
    ) async {
        // macOS スクリーン座標系 (左下が原点) から CGWindowList の座標系 (左上が原点) に変換
        let screenHeight = screen.frame.height
        let captureRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            isSnapping = false
            return
        }

        let recognized = await recognizeTextFromCGImage(cgImage)
        let trimmed = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastRecognizedText = trimmed

        if !trimmed.isEmpty {
            let centerPoint = CGPoint(x: rect.midX, y: rect.origin.y + rect.height)
            if let completion = completion {
                completion(trimmed, centerPoint)
            } else {
                // デフォルト: オーバーレイHUD表示 & チャット解説
                EnglishHUDOverlayController.shared.showHUD(text: trimmed, at: centerPoint)
            }
        }

        self.isSnapping = false
    }

    private func recognizeTextFromCGImage(_ cgImage: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: "")
                        return
                    }

                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    let fullText = recognizedStrings.joined(separator: " ")
                    continuation.resume(returning: fullText)
                }

                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US", "ja-JP"]
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

// MARK: - 🖱️ スニッピング用ドラッグオーバーレイビュー (SwiftUI)

private struct ScreenSnipOverlayView: View {
    let screenFrame: CGRect
    let onSelectionComplete: (CGRect?) -> Void

    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var body: some View {
        ZStack {
            // Background Dim
            Color.black.opacity(0.25)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())

            // Hint Text
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "character.cursor.ibeam")
                    Text("英語の文章や単語をマウスで囲んでください (ESCでキャンセル)")
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(Capsule())
                .padding(.top, 40)
                Spacer()
            }

            // Drag Selection Box
            if let rect = selectionRect {
                Path { path in
                    path.addRect(rect)
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                .background(
                    Rectangle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                )
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    let rect = selectionRect
                    onSelectionComplete(rect)
                }
        )
        .onExitCommand {
            onSelectionComplete(nil)
        }
    }
}
