import Foundation

public struct WebSearchResultItem: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let title: String
    public let snippet: String
    public let url: String

    public init(title: String, snippet: String, url: String = "") {
        self.title = title
        self.snippet = snippet
        self.url = url
    }
}

public final class WebSearchService: @unchecked Sendable {
    public static let shared = WebSearchService()

    private init() {}

    /// 天気クエリかどうかを判定
    public func isWeatherQuery(_ text: String) -> Bool {
        let keywords = ["天気", "てんき", "気温", "雨", "降水確率", "傘", "あめ", "晴れ", "曇り", "weather"]
        return keywords.contains { text.contains($0) }
    }

    /// 日本全国47都道府県および主要都市の緯度経度テーブル
    private let prefectureCoordinates: [(name: String, lat: Double, lon: Double)] = [
        ("静岡", 34.9756, 138.3828),
        ("浜松", 34.7108, 137.7261),
        ("東京", 35.6895, 139.6917),
        ("横浜", 35.4437, 139.6380),
        ("神奈川", 35.4437, 139.6380),
        ("大阪", 34.6937, 135.5023),
        ("名古屋", 35.1815, 136.9066),
        ("愛知", 35.1815, 136.9066),
        ("京都", 35.0116, 135.7681),
        ("札幌", 43.0618, 141.3545),
        ("北海道", 43.0618, 141.3545),
        ("福岡", 33.5904, 130.4017),
        ("神戸", 34.6901, 135.1955),
        ("兵庫", 34.6901, 135.1955),
        ("埼玉", 35.8617, 139.6455),
        ("さいたま", 35.8617, 139.6455),
        ("千葉", 35.6074, 140.1065),
        ("仙台", 38.2682, 140.8694),
        ("宮城", 38.2682, 140.8694),
        ("広島", 34.3853, 132.4553),
        ("那覇", 26.2124, 127.6809),
        ("沖縄", 26.2124, 127.6809),
        ("青森", 40.8244, 140.7400),
        ("岩手", 39.7036, 141.1527),
        ("盛岡", 39.7036, 141.1527),
        ("秋田", 39.7186, 140.1024),
        ("山形", 38.2554, 140.3396),
        ("福島", 37.7608, 140.4748),
        ("茨城", 36.3659, 140.4712),
        ("水戸", 36.3659, 140.4712),
        ("栃木", 36.5658, 139.8836),
        ("宇都宮", 36.5658, 139.8836),
        ("群馬", 36.3911, 139.0608),
        ("前橋", 36.3911, 139.0608),
        ("新潟", 37.9022, 139.0236),
        ("富山", 36.6953, 137.2113),
        ("石川", 36.5947, 136.6256),
        ("金沢", 36.5947, 136.6256),
        ("福井", 36.0641, 136.2196),
        ("山梨", 35.6642, 138.5684),
        ("甲府", 35.6642, 138.5684),
        ("長野", 36.6513, 138.1810),
        ("岐阜", 35.4233, 136.7607),
        ("三重", 34.7303, 136.5086),
        ("津", 34.7303, 136.5086),
        ("滋賀", 35.0045, 135.8686),
        ("大津", 35.0045, 135.8686),
        ("奈良", 34.6851, 135.8048),
        ("和歌山", 34.2260, 135.1675),
        ("鳥取", 35.5011, 134.2351),
        ("島根", 35.4723, 133.0505),
        ("松江", 35.4723, 133.0505),
        ("岡山", 34.6618, 133.9350),
        ("山口", 34.1785, 131.4737),
        ("徳島", 34.0704, 134.5548),
        ("香川", 34.3401, 134.0434),
        ("高松", 34.3401, 134.0434),
        ("愛媛", 33.8417, 132.7661),
        ("松山", 33.8417, 132.7661),
        ("高知", 33.5597, 133.5311),
        ("佐賀", 33.2635, 130.3009),
        ("長崎", 32.7503, 129.8777),
        ("熊本", 32.7898, 130.7417),
        ("大分", 33.2382, 131.6126),
        ("宮崎", 31.9077, 131.4202),
        ("鹿児島", 31.5966, 130.5571)
    ]

    /// 地名のジオコーディング（静的テーブル + 動的Open-Meteo Geocoding API）
    private func resolveCoordinates(for text: String) async -> (cityName: String, lat: Double, lon: Double) {
        // 1. 静的テーブルからマッチング
        for item in prefectureCoordinates {
            if text.contains(item.name) {
                return (item.name, item.lat, item.lon)
            }
        }

        // 2. 動的ジオコーディング検索
        // テキストから地名らしい単語を抽出して検索
        let cleanedQuery = text.replacingOccurrences(of: "の天気", with: "")
            .replacingOccurrences(of: "天気", with: "")
            .replacingOccurrences(of: "教えて", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let encoded = cleanedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=ja&format=json") {
            var req = URLRequest(url: geoURL)
            req.timeoutInterval = 3
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let name = first["name"] as? String,
               let lat = first["latitude"] as? Double,
               let lon = first["longitude"] as? Double {
                return (name, lat, lon)
            }
        }

        // デフォルトは東京
        return ("東京", 35.6895, 139.6917)
    }

    /// 天気情報の取得（Open-Meteo API: 無料・APIキー不要）
    public func fetchWeather(for text: String) async -> WebSearchResultItem? {
        let (targetCity, lat, lon) = await resolveCoordinates(for: text)

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FTokyo"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let dates = daily["time"] as? [String],
                  let maxTemps = daily["temperature_2m_max"] as? [Double],
                  let minTemps = daily["temperature_2m_min"] as? [Double],
                  let precips = daily["precipitation_probability_max"] as? [Double],
                  let codes = daily["weather_code"] as? [Int] else {
                return nil
            }

            var summaryLines: [String] = []
            let count = min(3, dates.count)
            for i in 0..<count {
                let dateStr = dates[i]
                let maxT = maxTemps.indices.contains(i) ? "\(maxTemps[i])℃" : "-"
                let minT = minTemps.indices.contains(i) ? "\(minTemps[i])℃" : "-"
                let precip = precips.indices.contains(i) ? "\(Int(precips[i]))%" : "-"
                let weatherText = codes.indices.contains(i) ? weatherCodeToJapanese(codes[i]) : "不明"

                let label = (i == 0) ? "今日 (\(dateStr))" : ((i == 1) ? "明日 (\(dateStr))" : "明後日 (\(dateStr))")
                summaryLines.append("・\(label): \(weatherText), 最高気温: \(maxT), 最低気温: \(minT), 降水確率: \(precip)")
            }

            let snippet = "【\(targetCity)の最新天気予報データ】\n" + summaryLines.joined(separator: "\n")
            return WebSearchResultItem(
                title: "\(targetCity)の天気予報 (Open-Meteo)",
                snippet: snippet,
                url: "https://open-meteo.com"
            )
        } catch {
            return nil
        }
    }

    /// 一般Web検索（DuckDuckGo Instant Answer & Web）
    public func searchWeb(query: String) async -> [WebSearchResultItem] {
        var results: [WebSearchResultItem] = []

        // 天気クエリの場合は天気を最優先で取得
        if isWeatherQuery(query) {
            if let weatherItem = await fetchWeather(for: query) {
                results.append(weatherItem)
            }
        }

        // DuckDuckGo Instant Answer API
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let ddgURL = URL(string: "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1") {
            var req = URLRequest(url: ddgURL)
            req.timeoutInterval = 4
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let abstract = json["AbstractText"] as? String, !abstract.isEmpty {
                    let heading = json["Heading"] as? String ?? query
                    let sourceURL = json["AbstractURL"] as? String ?? ""
                    results.append(WebSearchResultItem(title: heading, snippet: abstract, url: sourceURL))
                }
            }
        }

        return results
    }

    /// WMO Weather Code を日本語に変換
    private func weatherCodeToJapanese(_ code: Int) -> String {
        switch code {
        case 0: return "快晴 ☀️"
        case 1: return "晴れ 🌤️"
        case 2: return "一部曇り ⛅"
        case 3: return "曇り ☁️"
        case 45, 48: return "霧 🌫️"
        case 51, 53, 55: return "小雨 🌦️"
        case 61, 63, 65: return "雨 🌧️"
        case 71, 73, 75: return "雪 ❄️"
        case 80, 81, 82: return "にわか雨 🌧️"
        case 95, 96, 99: return "雷雨 ⚡"
        default: return "曇りがち ☁️"
        }
    }
}
