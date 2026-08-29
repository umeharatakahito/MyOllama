import Foundation
import Carbon
import AppKit

@MainActor
public final class CarbonHotKeyService {
    public static let shared = CarbonHotKeyService()

    private var hotKeyRefE: EventHotKeyRef?
    private var hotKeyRefS: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {
        registerGlobalHotKeys()
    }

    /// Carbon API `RegisterEventHotKey` を使って OS レベルでホットキーを登録
    public func registerGlobalHotKeys() {
        // 1. ハンドラーの登録
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                if hotKeyID.id == 1 {
                    // Cmd + Shift + E: 選択テキスト翻訳（無ければスニップ）
                    print("🎯 [HotKey] Cmd + Shift + E triggered")
                    Task { @MainActor in
                        ScreenTextSelectionService.shared.triggerEnglishAssistant()
                    }
                    return noErr
                } else if hotKeyID.id == 2 {
                    // Cmd + Shift + S: 画面範囲選択スニッピング OCR 直接起動
                    print("🎯 [HotKey] Cmd + Shift + S triggered")
                    Task { @MainActor in
                        ScreenTextSelectionService.shared.startScreenSnip()
                    }
                    return noErr
                }
            }
            return OSStatus(eventNotHandledErr)
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard installStatus == noErr else {
            print("❌ [HotKey] InstallEventHandler failed: \(installStatus)")
            return
        }

        let signature = OSType(0x4D594F4C) // 'MYOL'
        let modifiers = UInt32(cmdKey | shiftKey)

        // 2. Cmd + Shift + E (kVK_ANSI_E = 0x0E = 14) の登録
        let hotKeyIDE = EventHotKeyID(signature: signature, id: 1)
        let statusE = RegisterEventHotKey(
            UInt32(kVK_ANSI_E),
            modifiers,
            hotKeyIDE,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefE
        )
        print("⌨️ [HotKey] RegisterEventHotKey (Cmd+Shift+E): status=\(statusE)")

        // 3. Cmd + Shift + S (kVK_ANSI_S = 0x01 = 1) の登録
        let hotKeyIDS = EventHotKeyID(signature: signature, id: 2)
        let statusS = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            modifiers,
            hotKeyIDS,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefS
        )
        print("⌨️ [HotKey] RegisterEventHotKey (Cmd+Shift+S): status=\(statusS)")
    }
}
