#!/bin/bash
set -e

# カレントディレクトリをスクリプトのあるディレクトリの親（プロジェクトルート）に設定
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

APP_NAME="MyOllama"
BUILD_CONFIG="release"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building ${APP_NAME} (${BUILD_CONFIG})..."
swift build -c ${BUILD_CONFIG}

BIN_PATH="$(swift build -c ${BUILD_CONFIG} --show-bin-path)/${APP_NAME}"

echo "📦 Packaging ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 実行ファイルをコピー
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"

# 3Dモデル・アセットをResourcesにコピー
if [ -d "assets/mascot" ]; then
    cp -R assets/mascot "${RESOURCES_DIR}/"
fi

# Info.plist を生成
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.myollama.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>音声入力のためにマイクを使用します。</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>音声をテキストに変換してメッセージを入力するために音声認識を使用します。</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.myollama.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>myollama</string>
            </array>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

echo "✅ App bundle created: ${BUNDLE_DIR}"
echo "🚀 You can launch it with: open ${BUNDLE_DIR} or ./scripts/run_app.sh"
