import SwiftUI
import SceneKit
import AppKit

// MARK: - Mascot Manifest Loader
public struct MascotManifest {
    public struct Part {
        public let url: URL
        public let role: String
        public let minY: Double
        public let maxY: Double
    }

    public let height: Double
    public let parts: [Part]
    public let skeletalURL: URL?
    public let directory: URL

    /// 3Dモデルアセットの探索先候補
    public static var candidateDirectories: [URL] {
        var list: [URL] = []

        // 1. Bundle resources
        if let bundleURL = Bundle.main.resourceURL {
            list.append(bundleURL.appendingPathComponent("mascot"))
            list.append(bundleURL.appendingPathComponent("assets/mascot"))
        }

        // 2. AI-trading プロジェクト
        let aiTradingMascot = URL(fileURLWithPath: "/Users/umeharatakahito/program/AI-trading/assets/mascot")
        list.append(aiTradingMascot)

        // 3. MyOllama ローカル
        let myOllamaMascot = URL(fileURLWithPath: "/Users/umeharatakahito/program/MyOllama/assets/mascot")
        list.append(myOllamaMascot)

        return list
    }

    public static func load() -> MascotManifest? {
        for dir in candidateDirectories {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }

            let animated = dir.appendingPathComponent("ZundamonIdle.usdc")
            let staticModel = dir.appendingPathComponent("Zundamon.usdc")
            let hasSkeletal = FileManager.default.fileExists(atPath: animated.path) || FileManager.default.fileExists(atPath: staticModel.path)

            if hasSkeletal {
                let skeletal = FileManager.default.fileExists(atPath: animated.path) ? animated : staticModel
                return MascotManifest(
                    height: 1.0,
                    parts: [],
                    skeletalURL: skeletal,
                    directory: dir
                )
            }

            let file = dir.appendingPathComponent("mascot.json")
            if let data = try? Data(contentsOf: file),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rows = root["parts"] as? [[String: Any]] {
                let parts = rows.compactMap { row -> Part? in
                    guard let name = row["file"] as? String else { return nil }
                    let url = dir.appendingPathComponent(name)
                    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                    return Part(
                        url: url,
                        role: (row["role"] as? String) ?? "body",
                        minY: (row["min_y"] as? Double) ?? 0,
                        maxY: (row["max_y"] as? Double) ?? 1
                    )
                }
                if !parts.isEmpty {
                    return MascotManifest(
                        height: (root["height"] as? Double) ?? 1.0,
                        parts: parts,
                        skeletalURL: nil,
                        directory: dir
                    )
                }
            }
        }
        return nil
    }
}

// MARK: - SceneKit NSViewRepresentable
public struct ZundamonSceneRepresentable: NSViewRepresentable {
    public let manifest: MascotManifest
    public let isSpeaking: Bool
    public let isThinking: Bool
    public let isListening: Bool

    public init(manifest: MascotManifest, isSpeaking: Bool, isThinking: Bool, isListening: Bool) {
        self.manifest = manifest
        self.isSpeaking = isSpeaking
        self.isThinking = isThinking
        self.isListening = isListening
    }

    public func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        view.scene = buildScene()
        view.rendersContinuously = true
        view.isPlaying = true
        playEmbeddedAnimations(in: view.scene?.rootNode)
        return view
    }

    public func updateNSView(_ view: SCNView, context: Context) {
        view.isPlaying = true
        view.scene?.isPaused = false
        playEmbeddedAnimations(in: view.scene?.rootNode)

        guard let figure = view.scene?.rootNode.childNode(withName: "figure", recursively: false) else { return }

        // 1. 発話中の元気な身振り手振り＆リズミカルなジャンプ
        if isSpeaking {
            if figure.action(forKey: "speakingActions") == nil {
                // 上下に弾む
                let moveUp = SCNAction.moveBy(x: 0, y: 0.045, z: 0, duration: 0.15)
                let moveDown = SCNAction.moveBy(x: 0, y: -0.045, z: 0, duration: 0.15)
                let bounceSeq = SCNAction.sequence([moveUp, moveDown])

                // 左右に身振りを交えて揺れる
                let rotLeft = SCNAction.rotateBy(x: 0, y: 0.08, z: 0.05, duration: 0.3)
                let rotRight = SCNAction.rotateBy(x: 0, y: -0.16, z: -0.10, duration: 0.6)
                let rotCenter = SCNAction.rotateBy(x: 0, y: 0.08, z: 0.05, duration: 0.3)
                let swaySeq = SCNAction.sequence([rotLeft, rotRight, rotCenter])

                let group = SCNAction.group([
                    SCNAction.repeatForever(bounceSeq),
                    SCNAction.repeatForever(swaySeq)
                ])
                figure.runAction(group, forKey: "speakingActions")
            }
        } else {
            if figure.action(forKey: "speakingActions") != nil {
                figure.removeAction(forKey: "speakingActions")
                figure.position.y = -0.85
                figure.eulerAngles.y = 0
            }
        }

        // 2. 音声入力中（リスニング中・耳を澄ませて聞くポーズ）
        if isListening && !isSpeaking {
            if figure.action(forKey: "listeningPose") == nil {
                // 少し手前に乗り出し、首を傾けて耳を澄ますポーズ
                let leanForward = SCNAction.rotateTo(x: figure.eulerAngles.x + 0.08, y: 0.15, z: 0.18, duration: 0.25)
                // 耳を傾けて相槌（頷き）を打つ
                let nodDown = SCNAction.rotateBy(x: 0.04, y: 0, z: 0, duration: 0.4)
                let nodUp = SCNAction.rotateBy(x: -0.04, y: 0, z: 0, duration: 0.4)
                let nodSeq = SCNAction.sequence([nodDown, nodUp])

                let combined = SCNAction.sequence([
                    leanForward,
                    SCNAction.repeatForever(nodSeq)
                ])
                figure.runAction(combined, forKey: "listeningPose")
            }
        } else {
            if figure.action(forKey: "listeningPose") != nil {
                figure.removeAction(forKey: "listeningPose")
                let reset = SCNAction.rotateTo(x: -.pi / 2, y: 0, z: 0, duration: 0.25)
                figure.runAction(reset)
            }
        }

        // 3. 思考中（首をかしげるポーズ）
        if isThinking && !isSpeaking && !isListening {
            if figure.action(forKey: "thinkingTilt") == nil {
                let tilt = SCNAction.rotateTo(x: figure.eulerAngles.x, y: 0, z: -0.15, duration: 0.3)
                figure.runAction(tilt, forKey: "thinkingTilt")
            }
        } else {
            if figure.action(forKey: "thinkingTilt") != nil {
                let resetTilt = SCNAction.rotateTo(x: -.pi / 2, y: 0, z: 0, duration: 0.3)
                figure.runAction(resetTilt, forKey: "thinkingTilt")
            }
        }
    }

    private func playEmbeddedAnimations(in root: SCNNode?) {
        root?.enumerateChildNodes { node, _ in
            for key in node.animationKeys {
                guard let player = node.animationPlayer(forKey: key) else { continue }
                player.animation.repeatCount = .greatestFiniteMagnitude
                if player.paused { player.play() }
            }
        }
    }

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        let figure = SCNNode()
        figure.name = "figure"
        var usesAnimatedUSD = false

        if let skeletalURL = manifest.skeletalURL,
           let loaded = try? SCNScene(url: skeletalURL, options: nil) {
            usesAnimatedUSD = skeletalURL.lastPathComponent == "ZundamonIdle.usdc"
            for child in loaded.rootNode.childNodes {
                child.removeFromParentNode()
                figure.addChildNode(child)
            }
            applySkeletalTextures(to: figure, dir: manifest.directory)
            playEmbeddedAnimations(in: figure)
            // Blender/USDはZ-up、SceneKit画面はY-up
            figure.eulerAngles.x = -.pi / 2
        } else {
            for part in manifest.parts {
                guard let loaded = try? SCNScene(url: part.url, options: nil) else { continue }
                let holder = SCNNode()
                for child in loaded.rootNode.childNodes { holder.addChildNode(child) }
                figure.addChildNode(holder)
            }
        }

        let scale = manifest.height > 0 ? 1.7 / manifest.height : 1.0
        figure.scale = SCNVector3(scale, scale, scale)
        figure.position = SCNVector3(0, -0.85, 0)
        scene.rootNode.addChildNode(figure)

        // Camera
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.01
        if usesAnimatedUSD {
            camera.position = SCNVector3(0, 0.15, 2.3)
        } else {
            camera.position = SCNVector3(0, 0.15, -2.3)
            camera.eulerAngles = SCNVector3(0, Double.pi, 0)
        }
        scene.rootNode.addChildNode(camera)

        // Lights
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .directional
        light.light?.intensity = 680
        light.position = SCNVector3(-0.6, 1.4, 2.2)
        light.look(at: SCNVector3(0, 0.2, 0))
        scene.rootNode.addChildNode(light)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 540
        scene.rootNode.addChildNode(ambient)

        return scene
    }

    private func applySkeletalTextures(to root: SCNNode, dir: URL) {
        root.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                guard let name = material.name else { continue }
                let url = dir.appendingPathComponent("\(name).png")
                if let image = NSImage(contentsOf: url) {
                    material.diffuse.contents = image
                }
                material.transparencyMode = .aOne
                material.blendMode = .alpha
                material.isDoubleSided = true
            }
        }
    }
}

// MARK: - Zundamon 3D Mascot Panel View (Floating / Embedded)
public struct Zundamon3DView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var voicevox = VoicevoxService.shared
    @ObservedObject private var speechRecognizer = SpeechRecognitionService.shared
    public var isFloatingWindow: Bool = false
    @State private var manifest: MascotManifest?

    public init(viewModel: ChatViewModel, isFloatingWindow: Bool = false) {
        self.viewModel = viewModel
        self.isFloatingWindow = isFloatingWindow
    }

    private var isUserListening: Bool {
        speechRecognizer.isRecording || speechRecognizer.isAlwaysListening
    }

    public var body: some View {
        if isFloatingWindow {
            // フローティング時：完全に枠なし・透明なキャラクターのみ
            ZStack(alignment: .bottom) {
                // 3D Scene
                if let manifest = manifest {
                    ZundamonSceneRepresentable(
                        manifest: manifest,
                        isSpeaking: voicevox.isSpeaking,
                        isThinking: viewModel.isGenerating,
                        isListening: isUserListening
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                }

                // 足元のミニステータスバブル（喋り中・聞き取り中のみ表示）
                if voicevox.isSpeaking {
                    HStack(spacing: 4) {
                        Text("🗣️ 喋り中なのだ！")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)

                        Button(action: {
                            voicevox.stop()
                            viewModel.stopSpeaking()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.9), in: Capsule())
                    .padding(.bottom, 8)
                    .shadow(radius: 4)
                } else if isUserListening {
                    Text("👂 聞いてるのだ！")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.9), in: Capsule())
                        .padding(.bottom, 8)
                        .shadow(radius: 4)
                }
            }
            .onAppear {
                self.manifest = MascotManifest.load()
            }
        } else {
            // チャットウィンドウ埋め込み時
            VStack(spacing: 4) {
                // Header Info Tag
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(voicevox.isSpeaking ? Color.green : (isUserListening ? Color.purple : Color.blue))
                            .frame(width: 7, height: 7)
                        Text(voicevox.isSpeaking ? "🗣️ 喋り中なのだ！" : (isUserListening ? "👂 聞いてるのだ！" : (viewModel.isGenerating ? "🧠 考え中..." : "ずんだもん (3D)")))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // フローティング小窓化ボタン
                    Button(action: {
                        FloatingMascotController.shared.show(viewModel: viewModel)
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("デスクトップ上のフローティング小窓として常に手前に表示")

                    if voicevox.isSpeaking {
                        Button(action: {
                            voicevox.stop()
                            viewModel.stopSpeaking()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("音声を停止")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                // 3D Scene
                if let manifest = manifest {
                    ZundamonSceneRepresentable(
                        manifest: manifest,
                        isSpeaking: voicevox.isSpeaking,
                        isThinking: viewModel.isGenerating,
                        isListening: isUserListening
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RadialGradient(
                            colors: [Color.green.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 140
                        )
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.green.opacity(0.6))
                        Text("3Dずんだもん読込中...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 180, height: 240)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(voicevox.isSpeaking ? Color.green.opacity(0.6) : (isUserListening ? Color.purple.opacity(0.6) : Color.primary.opacity(0.12)), lineWidth: (voicevox.isSpeaking || isUserListening) ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            .onAppear {
                self.manifest = MascotManifest.load()
            }
        }
    }
}
