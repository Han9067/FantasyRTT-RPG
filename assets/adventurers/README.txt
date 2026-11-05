모험가 외형 전체 — 남성 32종 / 여성 32종

현재 게임의 모험가 만들기 화면 번호 기준입니다. appearance-index.json에 내부 ID와 설명을 담았습니다.
각 폴더: idle=대기 4프레임(330ms/프레임), walk=이동 8프레임(105ms/프레임).
full=머리+기본 튜닉 몸통, head=머리, body=몸통. 모두 투명 배경 PNG, 32×36px 공통 캔버스. 그림자와 무기 없음.
_sheet.png는 같은 크기 프레임을 왼쪽부터 순서대로 배치한 가로 스프라이트 시트입니다.
기본 방향이며 반대 방향은 좌우 반전합니다. nearest-neighbor/Point 필터로 확대하세요.
눈 깜빡임은 별도 실시간 효과이므로 이 추출본은 눈 뜬 상태로 통일했습니다.
원본은 PNG 파일이 아닌 Canvas 렌더링 코드입니다. source/character-renderer.js에 현재 얼굴 수정사항과 모션을 포함한 원본을 동봉했습니다.
source/armor-appearance-reference.js는 장비 착용 몸통용 참고 코드이며 일부는 게임의 RaidMap 의존성이 있습니다. 본 PNG는 생성 화면의 기본 복장 64종입니다.
남녀 overview 파일은 번호별 미리보기입니다.
