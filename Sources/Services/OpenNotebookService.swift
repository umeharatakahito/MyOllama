import Foundation
import Combine
import AppKit

@MainActor
public final class OpenNotebookService: ObservableObject {
    public static let shared = OpenNotebookService()

    public static let defaultObsidianVaultPath = "/Users/\(NSUserName())/Library/CloudStorage/OneDrive-個人用/obsidian"
    public static let openNotebookRootPath = "/Users/\(NSUserName())/open-notebook"

    @Published public var isServerRunning: Bool = false
    @Published public var isStartingServer: Bool = false
    @Published public var notebooks: [OpenNotebookItem] = []
    @Published public var obsidianNotes: [ObsidianNoteItem] = []
    @Published public var errorMessage: String? = nil

    private let baseURL = URL(string: "http://localhost:5055")!
    private var dbProcess: Process?
    private var apiProcess: Process?

    private init() {
        Task {
            await checkServerHealth()
            loadObsidianNotes()
        }
    }

    // MARK: - Server Health & Control

    public func checkServerHealth() async {
        let url = baseURL.appendingPathComponent("api/notebooks")
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.isServerRunning = true
                if let decoded = try? JSONDecoder().decode([OpenNotebookItem].self, from: data) {
                    self.notebooks = decoded
                }
            } else {
                self.isServerRunning = false
            }
        } catch {
            self.isServerRunning = false
        }
    }

    /// Open Notebook サーバー（SurrealDB + API）をローカルで起動
    public func startServer() {
        guard !isServerRunning && !isStartingServer else { return }
        isStartingServer = true
        errorMessage = nil

        let openNotebookDir = Self.openNotebookRootPath

        Task.detached(priority: .userInitiated) {
            // 1. SurrealDB 起動
            let dbProc = Process()
            dbProc.executableURL = URL(fileURLWithPath: "/bin/sh")
            dbProc.arguments = ["-c", "export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin && cd \(openNotebookDir) && surreal start --user root --pass root rocksdb://mydatabase.db"]
            try? dbProc.run()

            // 3秒待機
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            // 2. API サーバー起動
            let apiProc = Process()
            apiProc.executableURL = URL(fileURLWithPath: "/bin/sh")
            apiProc.arguments = ["-c", "export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin && cd \(openNotebookDir) && uv run --env-file .env run_api.py"]
            try? apiProc.run()

            // さらに3秒待機してヘルスチェック
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            await MainActor.run {
                self.dbProcess = dbProc
                self.apiProcess = apiProc
                self.isStartingServer = false
                Task {
                    await self.checkServerHealth()
                }
            }
        }
    }

    public func stopServer() {
        dbProcess?.terminate()
        apiProcess?.terminate()
        dbProcess = nil
        apiProcess = nil
        isServerRunning = false
    }

    // MARK: - Open Notebook API Methods

    public func fetchNotebooks() async throws -> [OpenNotebookItem] {
        let url = baseURL.appendingPathComponent("api/notebooks")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode([OpenNotebookItem].self, from: data)
        self.notebooks = decoded
        return decoded
    }

    public func fetchSources(for notebookId: String? = nil) async throws -> [OpenNotebookSource] {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("api/sources"), resolvingAgainstBaseURL: false)!
        if let nbId = notebookId {
            urlComponents.queryItems = [URLQueryItem(name: "notebook_id", value: nbId)]
        }
        guard let url = urlComponents.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([OpenNotebookSource].self, from: data)
    }

    /// RAG 検索（Open Notebook API 優先、停止時はローカルObsidian検索にフォールバック）
    public func searchRAG(query: String, limit: Int = 5) async -> [OpenNotebookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 1. Open Notebook API が稼働中の場合は API 検索
        if isServerRunning {
            if let results = try? await searchOpenNotebookAPI(query: trimmed, limit: limit), !results.isEmpty {
                return results
            }
        }

        // 2. フォールバック: ローカル Obsidian Vault の全文検索
        return searchLocalObsidian(query: trimmed, limit: limit)
    }

    private func searchOpenNotebookAPI(query: String, limit: Int) async throws -> [OpenNotebookSearchResult] {
        let url = baseURL.appendingPathComponent("api/search")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10

        let body: [String: Any] = [
            "query": query,
            "type": "text",
            "limit": limit,
            "search_sources": true,
            "search_notes": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        return results.compactMap { dict in
            let title = (dict["title"] as? String) ?? (dict["id"] as? String) ?? "無題"
            let content = (dict["content"] as? String) ?? ""
            let score = dict["score"] as? Double
            let type = dict["type"] as? String
            var strDict: [String: String] = [:]
            for (k, v) in dict {
                strDict[k] = "\(v)"
            }
            return OpenNotebookSearchResult(title: title, content: content, score: score, type: type, rawDict: strDict)
        }
    }

    // MARK: - Local Obsidian Vault Scan & Direct Search

    public func loadObsidianNotes() {
        let vaultURL = URL(fileURLWithPath: Self.defaultObsidianVaultPath)
        guard FileManager.default.fileExists(atPath: vaultURL.path) else { return }

        var items: [ObsidianNoteItem] = []
        let enumerator = FileManager.default.enumerator(at: vaultURL, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }

            let relPath = fileURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
            let title = fileURL.deletingPathExtension().lastPathComponent
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modDate = resourceValues?.contentModificationDate ?? Date()
            let fileSize = Int64(resourceValues?.fileSize ?? 0)

            items.append(ObsidianNoteItem(relPath: relPath, title: title, url: fileURL, modifiedDate: modDate, fileSize: fileSize))
        }

        self.obsidianNotes = items.sorted(by: { $0.modifiedDate > $1.modifiedDate })
    }

    public func readObsidianNoteContent(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    public func searchLocalObsidian(query: String, limit: Int = 5) -> [OpenNotebookSearchResult] {
        let terms = query.lowercased().split(separator: " ")
        guard !terms.isEmpty else { return [] }

        var matches: [(item: ObsidianNoteItem, content: String, score: Double)] = []

        for item in obsidianNotes {
            guard let content = readObsidianNoteContent(at: item.url) else { continue }
            let lowerContent = content.lowercased()
            let lowerTitle = item.title.lowercased()

            var score: Double = 0
            for term in terms {
                let termStr = String(term)
                if lowerTitle.contains(termStr) {
                    score += 5.0
                }
                let count = lowerContent.components(separatedBy: termStr).count - 1
                if count > 0 {
                    score += min(Double(count) * 0.5, 3.0)
                }
            }

            if score > 0 {
                matches.append((item: item, content: content, score: score))
            }
        }

        matches.sort(by: { $0.score > $1.score })

        return matches.prefix(limit).map { match in
            OpenNotebookSearchResult(
                title: match.item.title,
                content: match.content,
                score: match.score,
                type: "obsidian_file",
                rawDict: ["path": match.item.relPath]
            )
        }
    }
}
