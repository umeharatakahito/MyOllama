import Foundation
import AppKit

@MainActor
public final class ObsidianSyncService: ObservableObject {
    public static let shared = ObsidianSyncService()

    @Published public var activeNoteTitle: String? = nil
    @Published public var activeNoteContent: String? = nil
    @Published public var activeNoteURL: URL? = nil
    @Published public var isSyncingWithObsidian: Bool = false
    @Published public var lastEditTimestamp: Date? = nil

    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    private init() {}

    /// Obsidian Vault 内で「今まさに編集・閲覧されている最新のMDノート」を自動検出して読み込む
    public func syncLatestObsidianNote() -> (title: String, content: String)? {
        let vaultURL = URL(fileURLWithPath: OpenNotebookService.defaultObsidianVaultPath)
        guard FileManager.default.fileExists(atPath: vaultURL.path) else { return nil }

        var latestFile: (url: URL, date: Date, title: String)? = nil
        let enumerator = FileManager.default.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let modDate = values?.contentModificationDate ?? Date.distantPast

            if latestFile == nil || modDate > latestFile!.date {
                let title = fileURL.deletingPathExtension().lastPathComponent
                latestFile = (fileURL, modDate, title)
            }
        }

        guard let target = latestFile,
              let content = try? String(contentsOf: target.url, encoding: .utf8) else {
            return nil
        }

        setTargetNote(url: target.url, title: target.title)
        return (target.title, content)
    }

    /// 特定のObsidianノートを指定して壁打ち対象にセット＆ファイル監視開始
    public func setTargetNote(url: URL, title: String) {
        stopMonitoring()

        if let content = try? String(contentsOf: url, encoding: .utf8) {
            self.activeNoteTitle = title
            self.activeNoteContent = content
            self.activeNoteURL = url
            self.isSyncingWithObsidian = true
            self.lastEditTimestamp = Date()
            startMonitoring(fileURL: url)
        }
    }

    /// Obsidian Vault (myollamaフォルダ) 内に新規白紙ノートを作成し、Obsidian アプリを前面起動して開く
    public func createAndOpenBlankNoteInObsidian() -> (title: String, fileURL: URL)? {
        let vaultRoot = OpenNotebookService.defaultObsidianVaultPath
        let myOllamaURL = URL(fileURLWithPath: vaultRoot).appendingPathComponent("myollama")
        try? FileManager.default.createDirectory(at: myOllamaURL, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())
        let title = "新規壁打ち_\(timestamp)"
        let fileName = "\(title).md"
        let fileURL = myOllamaURL.appendingPathComponent(fileName)

        let initialContent = """
        # 📝 \(title)

        

        """

        try? initialContent.write(to: fileURL, atomically: true, encoding: .utf8)

        setTargetNote(url: fileURL, title: title)

        // Obsidian アプリを起動してそのノートを開く
        if let encodedPath = "myollama/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "obsidian://open?vault=obsidian&file=\(encodedPath)") {
            NSWorkspace.shared.open(url)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Obsidian", fileURL.path]
        try? proc.run()

        return (title, fileURL)
    }

    // MARK: - 🎨 Canvas Direct Write / Edit Engine (Obsidian画面に直接反映)

    /// アクティブなObsidianノートの末尾にテキストを直接追記（Obsidian側がリアルタイム自動リロード）
    @discardableResult
    public func appendToActiveNote(text: String) -> Bool {
        guard let url = activeNoteURL else { return false }
        let current = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let trimmedAppend = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppend.isEmpty else { return false }

        let newContent = current.isEmpty ? trimmedAppend : "\(current)\n\n\(trimmedAppend)\n"
        do {
            try newContent.write(to: url, atomically: true, encoding: .utf8)
            self.activeNoteContent = newContent
            self.lastEditTimestamp = Date()
            return true
        } catch {
            return false
        }
    }

    /// アクティブなObsidianノートの内容を丸ごと更新（Obsidian側がリアルタイム自動リロード）
    @discardableResult
    public func rewriteActiveNote(newContent: String) -> Bool {
        guard let url = activeNoteURL else { return false }
        do {
            try newContent.write(to: url, atomically: true, encoding: .utf8)
            self.activeNoteContent = newContent
            self.lastEditTimestamp = Date()
            return true
        } catch {
            return false
        }
    }

    /// ボタンを押していなくても、利用可能なObsidianノートを自動取得（なければ自動作成）
    @discardableResult
    public func ensureActiveNoteAvailable() -> Bool {
        if activeNoteURL != nil {
            return true
        }
        if syncLatestObsidianNote() != nil {
            return true
        }
        return createAndOpenBlankNoteInObsidian() != nil
    }

    /// AI応答テキストからCanvas編集タグ（<<<CANVAS_REPLACE>>> / <<<CANVAS_APPEND>>>）を解析してObsidianノートを直接更新
    /// タグがない場合でも、ユーザーが追記を求めていれば自動追記するフォールバック付き
    public func processAIResponseForCanvasUpdate(aiResponse: String, userPrompt: String = "") -> (cleanedResponse: String, didUpdateNote: Bool, actionDescription: String?) {
        // ノートが未選択の場合、自動で最新ノートを確保
        if activeNoteURL == nil {
            _ = ensureActiveNoteAvailable()
        }

        guard let activeURL = activeNoteURL else {
            return (aiResponse, false, nil)
        }

        var cleaned = aiResponse
        var didUpdate = false
        var actionDesc: String? = nil

        // 1. 全文置換/リライトパターン
        if let startRange = cleaned.range(of: "<<<CANVAS_REPLACE>>>"),
           let endRange = cleaned.range(of: "<<<END_CANVAS_REPLACE>>>") {
            let updateContent = String(cleaned[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !updateContent.isEmpty {
                if rewriteActiveNote(newContent: updateContent) {
                    didUpdate = true
                    actionDesc = "Obsidianのノート「\(activeNoteTitle ?? "ノート")」を直接リライトしたのだ！"
                }
            }
            cleaned.removeSubrange(startRange.lowerBound...endRange.upperBound)
        }

        // 2. 追記パターン (タグあり)
        else if let startRange = cleaned.range(of: "<<<CANVAS_APPEND>>>"),
           let endRange = cleaned.range(of: "<<<END_CANVAS_APPEND>>>") {
            let appendContent = String(cleaned[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !appendContent.isEmpty {
                if appendToActiveNote(text: appendContent) {
                    didUpdate = true
                    actionDesc = "Obsidianのノート「\(activeNoteTitle ?? "ノート")」に新しい内容を追記したのだ！"
                }
            }
            cleaned.removeSubrange(startRange.lowerBound...endRange.upperBound)
        }

        // 3. インテリジェント・フォールバック (タグなしだが、ユーザーが追記・執筆をお願いしていた場合)
        else {
            let promptLower = userPrompt.lowercased()
            let isAppendIntent = promptLower.contains("追記") || promptLower.contains("書いて") ||
                                 promptLower.contains("ノートに") || promptLower.contains("追加") ||
                                 promptLower.contains("メモして") || promptLower.contains("まとめて") ||
                                 promptLower.contains("obsidian")

            if isAppendIntent && !cleaned.isEmpty {
                let noteSnippet = "### 💡 ずんだもんメモ (\(Date().formatted()))\n" + cleaned
                if appendToActiveNote(text: noteSnippet) {
                    didUpdate = true
                    actionDesc = "Obsidianのノート「\(activeNoteTitle ?? "ノート")」に直接追記しておいたのだ！"
                }
            }
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty && didUpdate {
            cleaned = actionDesc ?? "Obsidianのノートを直接更新したのだ！Obsidianの画面を確認してみてね！✨"
        }

        return (cleaned, didUpdate, actionDesc)
    }

    // MARK: - File Monitoring (FSEvents / DispatchSource)

    private func startMonitoring(fileURL: URL) {
        stopMonitoring()
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        self.fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, let url = self.activeNoteURL else { return }
                if let updated = try? String(contentsOf: url, encoding: .utf8) {
                    self.activeNoteContent = updated
                    self.lastEditTimestamp = Date()
                }
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        self.fileMonitorSource = source
    }

    private func stopMonitoring() {
        if let src = fileMonitorSource {
            src.cancel()
            fileMonitorSource = nil
        }
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    /// 壁打ち連携を解除
    public func clearSync() {
        stopMonitoring()
        self.activeNoteTitle = nil
        self.activeNoteContent = nil
        self.activeNoteURL = nil
        self.isSyncingWithObsidian = false
    }
}
