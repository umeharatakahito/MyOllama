import Foundation

public enum OllamaError: LocalizedError, Sendable {
    case invalidURL
    case serverUnreachable(String)
    case httpError(statusCode: Int, message: String)
    case modelError(String)
    case decodingError(String)
    case noModelsAvailable
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "OllamaサーバーのURLが無効です。"
        case .serverUnreachable(let url):
            return "Ollamaサーバー (\(url)) に接続できません。Ollamaが起動しているか確認してください。"
        case .httpError(let code, let msg):
            if msg.contains("does not support image input") {
                return "選択中のモデルは画像入力（Vision）に対応していません。Vision対応モデル（qwen3.8等）を選択してください。"
            }
            return "Ollamaエラー (HTTP \(code)): \(msg)"
        case .modelError(let msg):
            if msg.contains("does not support image input") {
                return "選択中のモデルは画像入力（Vision）に対応していません。Vision対応モデル（qwen3.8等）を選択してください。"
            }
            return "モデルエラー: \(msg)"
        case .decodingError(let detail):
            return "レスポンスの解析に失敗しました: \(detail)"
        case .noModelsAvailable:
            return "利用可能なモデルが見つかりません。`ollama run <model>` でモデルをダウンロードしてください。"
        case .unknown(let msg):
            return "予期しないエラー: \(msg)"
        }
    }
}

public actor OllamaService {
    public static let shared = OllamaService()
    
    private var baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://127.0.0.1:11434")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    public func setBaseURL(_ url: URL) {
        self.baseURL = url
    }

    public func getBaseURL() -> URL {
        return self.baseURL
    }

    /// 利用可能なモデル一覧を取得
    public func fetchModels() async throws -> [OllamaModelInfo] {
        let endpoint = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OllamaError.serverUnreachable(baseURL.absoluteString)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.unknown("無効なHTTPレスポンスです。")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw OllamaError.httpError(statusCode: httpResponse.statusCode, message: errorText)
        }

        do {
            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return decoded.models
        } catch {
            throw OllamaError.decodingError(error.localizedDescription)
        }
    }

    /// チャットストリーミング
    public func sendChatStream(
        model: String,
        messages: [ChatMessage],
        think: Bool? = nil
    ) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream(String.self) { continuation in
            let task = Task {
                do {
                    let endpoint = baseURL.appendingPathComponent("api/chat")
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let payloadMessages = messages.compactMap { msg -> OllamaMessagePayload? in
                        let base64Images: [String]? = msg.imageDataList.isEmpty ? nil : msg.imageDataList.map { $0.base64EncodedString() }
                        return OllamaMessagePayload(role: msg.role.rawValue, content: msg.content, images: base64Images)
                    }

                    let chatRequest = OllamaChatRequest(
                        model: model,
                        messages: payloadMessages,
                        stream: true,
                        think: think
                    )

                    let requestData = try JSONEncoder().encode(chatRequest)
                    request.httpBody = requestData

                    let (asyncBytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaError.unknown("無効なHTTPレスポンス"))
                        return
                    }

                    let decoder = JSONDecoder()

                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            break
                        }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }

                        if let lineData = trimmed.data(using: .utf8) {
                            // エラーレスポンスのチェック
                            if let errorChunk = try? decoder.decode(OllamaErrorResponse.self, from: lineData),
                               let errorMsg = errorChunk.error, !errorMsg.isEmpty {
                                continuation.finish(throwing: OllamaError.modelError(errorMsg))
                                return
                            }

                            do {
                                let chunk = try decoder.decode(OllamaChatStreamChunk.self, from: lineData)
                                if let errorMsg = chunk.error, !errorMsg.isEmpty {
                                    continuation.finish(throwing: OllamaError.modelError(errorMsg))
                                    return
                                }
                                if let token = chunk.message?.content, !token.isEmpty {
                                    continuation.yield(token)
                                }
                                if chunk.done == true {
                                    break
                                }
                            } catch {
                                continue
                            }
                        }
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: OllamaError.httpError(statusCode: httpResponse.statusCode, message: "リクエストに失敗しました"))
                        return
                    }

                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
