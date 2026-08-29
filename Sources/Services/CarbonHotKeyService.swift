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
                    Task { @MainActor in
                        ScreenTextSelectionService.shared.triggerEnglishAssistant()
                    }
                    return noErr
                } else if hotKeyID.id == 2 {
                    // Cmd + Shift + S: 画面範囲選択スニッピング OCR 直接起動
                    Task { @MainActor in
                        ScreenTextSelectionService.shared.startScreenSnip()
                    }
                    return noErr
                }
            }
            return OSStatus(eventNotHandledErr)
        }

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else { return }

        let signature = OSType(0x4D594F4C) // 'MYOL'
        let modifiers = UInt32(cmdKey | shiftKey)

        // 2. Cmd + Shift + E (kVK_ANSI_E = 14) の登録
        let hotKeyIDE = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_E),
            modifiers,
            hotKeyIDE,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefE
        )

        // 3. Cmd + Shift + S (kVK_ANSI_S = 1) の登録
        let hotKeyIDS = EventHotKeyID(signature: signature, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            modifiers,
            hotKeyIDS,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefS
        )
    }
}
