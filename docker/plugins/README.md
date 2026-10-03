# docker/plugins — 직접 넣는 플러그인

여기에 넣은 `.jar` 는 서버가 기동할 때마다 `/data/plugins/` 로 복사됩니다.

- Geyser·Floodgate·ViaVersion 은 기동 스크립트(`docker/scripts/update-plugins.sh`)가 매번 최신을
  받으므로 넣지 않아도 됩니다.
- jar 는 git 에서 제외됩니다(`.gitignore` 의 `docker/plugins/*.jar`).
- 이 파일은 폴더를 저장소에 남기기 위한 것입니다. 폴더가 비어 있으면 기동 스크립트의 복사 단계가
  오류 줄을 남깁니다.
