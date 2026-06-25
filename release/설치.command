#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Directioner 설치 중..."

# Applications에 복사
cp -R "$DIR/Directioner.app" /Applications/Directioner.app 2>/dev/null || \
sudo cp -R "$DIR/Directioner.app" /Applications/Directioner.app

# 격리 속성 제거
xattr -dr com.apple.quarantine /Applications/Directioner.app

echo "✅ 설치 완료!"
echo ""
echo "앱을 실행합니다..."
open /Applications/Directioner.app
echo ""
echo "이 창을 닫아도 됩니다."
