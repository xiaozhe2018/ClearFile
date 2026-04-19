#!/bin/bash
set -euo pipefail

# ============================================================
# ClearFile 打包脚本
# 用法：
#   ./scripts/package.sh              # 构建 .app（不签名）
#   ./scripts/package.sh --sign       # 构建 + 签名
#   ./scripts/package.sh --notarize   # 构建 + 签名 + 公证
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="ClearFile"
BUNDLE_ID="com.clearfile.app"
VERSION="1.0.0"
BUILD_NUM="1"

OUTPUT_DIR="$PROJECT_DIR/dist"
APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"      # "Developer ID Application: Your Name (TEAMID)"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-}" # xcrun notarytool 的 keychain profile 名

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 ClearFile Packager v$VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. 编译 Release ──

echo "🔨 Building release..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -5
BINARY="$BUILD_DIR/arm64-apple-macosx/release/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "❌ 编译失败：找不到 $BINARY"
    exit 1
fi
echo "✅ Binary: $(du -h "$BINARY" | cut -f1) → $BINARY"

# ── 2. 构建 .app Bundle ──

echo "📁 Creating .app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 复制二进制
cp "$BINARY" "$APP_PATH/Contents/MacOS/$APP_NAME"

# 复制 Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_PATH/Contents/"

# 复制图标（如果存在）
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/"
    echo "  🎨 App icon copied"
fi

# PkgInfo
echo -n "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo "✅ .app bundle created: $APP_PATH"

# ── 2.5. Ad-hoc 签名（免费，不需要 Developer ID）──
# 把"已损毁"降级为"无法验证开发者"（右键可打开）

echo "🔐 Ad-hoc signing..."
codesign --force --deep --sign - "$APP_PATH" 2>/dev/null
echo "✅ Ad-hoc signed (bypasses 'damaged' error)"

# ── 3. Developer ID 签名（可选）──

if [[ "${1:-}" == "--sign" || "${1:-}" == "--notarize" ]]; then
    if [ -z "$SIGN_IDENTITY" ]; then
        echo ""
        echo "⚠️  需要设置 SIGN_IDENTITY 环境变量："
        echo "  export SIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\""
        echo ""
        echo "  查看可用证书："
        echo "  security find-identity -v -p codesigning"
        echo ""
        exit 1
    fi
    echo "🔐 Signing with: $SIGN_IDENTITY"
    codesign --force --deep --options runtime \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$PROJECT_DIR/Resources/ClearFile.entitlements" \
        "$APP_PATH"
    echo "✅ Signed"

    # 验证签名
    codesign --verify --deep --strict "$APP_PATH"
    echo "✅ Signature verified"
fi

# ── 4. 公证（可选）──

if [[ "${1:-}" == "--notarize" ]]; then
    if [ -z "$NOTARIZE_PROFILE" ]; then
        echo ""
        echo "⚠️  需要设置 NOTARIZE_PROFILE 环境变量："
        echo "  先存储凭证：xcrun notarytool store-credentials PROFILE_NAME"
        echo "  再设置：export NOTARIZE_PROFILE=\"PROFILE_NAME\""
        echo ""
        exit 1
    fi
    echo "📤 Creating ZIP for notarization..."
    ZIP_PATH="$OUTPUT_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "📤 Submitting to Apple..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "📌 Stapling..."
    xcrun stapler staple "$APP_PATH"
    rm -f "$ZIP_PATH"
    echo "✅ Notarized and stapled"
fi

# ── 5. 打 DMG（可选）──

if command -v create-dmg &>/dev/null; then
    echo "💿 Creating DMG..."
    rm -f "$DMG_PATH"
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --app-drop-link 400 185 \
        "$DMG_PATH" "$APP_PATH" 2>/dev/null || true
    if [ -f "$DMG_PATH" ]; then
        echo "✅ DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
    fi
else
    echo "💡 安装 create-dmg 可自动打 DMG："
    echo "   brew install create-dmg"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 打包完成"
echo ""
echo "  .app: $APP_PATH"
echo "  大小: $(du -sh "$APP_PATH" | cut -f1)"
echo ""
echo "  运行: open \"$APP_PATH\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
