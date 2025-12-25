#!/bin/bash
echo "[Script] 플러그인 강제 업데이트 시작!"

# 폴더가 없으면 에러가 날 수 있으니 강제 생성
mkdir -p /data/plugins

# 1. 기존 jar 삭제
find /data/plugins -maxdepth 1 -type f -name "*.jar" -delete

# 2. 파일 복사
if [ -d "/_staging/plugins" ]; then
    cp -rf /_staging/plugins/* /data/plugins/
    echo "[Script] 플러그인 복사 완료."
else
    echo "[Script] 경고: _staging 폴더가 없습니다."
fi