# 분열의 시대 · FantasyRTT-RPG

마법 없는 중세 내전 세계를 배경으로 하는 2D 도트 전략 RPG의 첫 프로토타입입니다.
현재 범위는 메인 메뉴와 캐릭터 생성 화면입니다. 월드맵과 전투는 아직 구현하지 않았습니다.

## 실행

Godot 4.6.3에서 `project.godot`를 가져온 뒤 F6가 아닌 F5로 프로젝트를 실행하세요.
추가 플러그인이나 서비스, 비밀 키는 필요하지 않습니다.

새 게임 → 이름 입력 → 남/여 선택 → 나이(16–40세) → 외형 선택.
성별별로 외형 4종이 있으며, 선택한 외형이 왼쪽 액자에 표시됩니다.
하단 캐릭터 생성 버튼은 다음 동작을 연결하지 않은 상태입니다.
가제는 '분열의 시대'이며 추후 변경할 수 있습니다.

## 클라우드에서 검증

```sh
cd /workspace/FantasyRTT-RPG
export XDG_DATA_HOME=/workspace/.godot-runtime/data
export XDG_CONFIG_HOME=/workspace/.godot-runtime/config
export XDG_CACHE_HOME=/workspace/.godot-runtime/cache
godot --headless --editor --import --quit
godot --headless --script res://tests/smoke.gd
```

GUI가 있는 환경에서는 `godot --path .`로 실행합니다.
Windows 실행파일은 아직 내보내지 않았습니다.

캐릭터는 프로젝트 내 코드에서 생성하는 원본 32×48 픽셀 스프라이트입니다.
한국어 글꼴은 Noto Sans CJK이며 사용 조건은 assets/fonts/LICENSE.txt에 있습니다.

## 웹 테스트 배포

`tools/build-web.sh`로 Godot 4.6.3의 Web 내보내기를 실행합니다.
같은 버전의 공식 export templates가 필요합니다. 단일 스레드 빌드이므로
GitHub Pages에서 별도 COOP/COEP 헤더 없이 실행할 수 있습니다.
`builds/web/`의 전체 파일이 배포 대상이며 `.wasm`과 `.pck`도 함께 필요합니다.

GitHub Pages를 사용할 경우 저장소 Settings → Pages → Build and deployment에서
Deploy from a branch, `gh-pages` 브랜치, `/ (root)`를 선택합니다.
소스는 main, 실행용 웹 파일은 gh-pages에 보관합니다.

## 버전 0.0.1

메인 메뉴 하단에 버전을 표시합니다. 이후 요청 단위 업데이트마다 마지막 숫자만 1 증가하며,
앞의 두 숫자는 사용자가 명시적으로 요청할 때만 변경합니다.
외형은 전투용 확장을 고려한 오른쪽 측면의 원본 32×48 픽셀 아트 8종입니다.
남성은 짧은 머리와 수염, 금발, 긴 수염, 머리띠와 묶은 머리로 구분하고,
여성은 땋은 머리, 낮게 묶은 머리, 짧은 단발, 높은 묶음 머리로 구분합니다.

## 버전 0.0.2

남녀 8종의 측면 외형을 모두 젊은 성인으로 다시 제작했습니다.
수염과 과도한 얼굴 음영을 제거하고 얼굴, 코, 턱과 몸의 비율을 조정했습니다.
현재 남성은 갈색 앞머리, 금발, 검은 짧은 머리, 적갈색 가르마로 구분하고,
여성은 어깨 길이 머리, 낮은 포니테일, 단발, 땋은 머리로 구분합니다.
외형 선택 카드에도 최근접 픽셀 필터를 적용했습니다.
