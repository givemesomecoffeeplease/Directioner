#!/bin/bash
set -e

PROJECT="$HOME/Desktop/app/ClickTrackInserter/ClickTrackInserter.xcodeproj"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
APP_NAME="ClickTrackInserter"
INSTALL_PATH="/Applications/Directioner.app"

echo "🔨 빌드 중 (Universal Binary: arm64 + x86_64)..."
xcodebuild -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build \
  2>&1 | grep -E "error:|warning:|BUILD"

# 최신 빌드 경로 자동 탐색
BUILD_APP=$(find "$DERIVED" -name "$APP_NAME.app" \
  -not -path "*/Index.noindex/*" \
  -newer "$PROJECT/project.pbxproj" 2>/dev/null | head -1)

if [ -z "$BUILD_APP" ]; then
  echo "❌ 빌드 결과물을 찾을 수 없습니다"
  exit 1
fi

echo "🛑 기존 앱 종료..."
pkill -x "$APP_NAME" 2>/dev/null || true
pkill -x "Directioner" 2>/dev/null || true
sleep 0.5

echo "🔐 손쉬운 사용 권한 초기화..."
tccutil reset Accessibility HanHee.Directioner 2>/dev/null || true

echo "📦 설치 중..."
rm -rf "$INSTALL_PATH"
cp -R "$BUILD_APP" "$INSTALL_PATH"

# CFBundleName 패치 (손쉬운 사용 목록에 표시되는 이름)
/usr/libexec/PlistBuddy -c "Set :CFBundleName Directioner" "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || true

echo "🚀 실행 중..."
open "$INSTALL_PATH"

echo "✅ 완료!"
