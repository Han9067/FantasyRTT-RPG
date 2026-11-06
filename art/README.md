# MedievalFantasyCharacters 편집용 원본

medieval에는 사용자 캐릭터 에셋과 최신 weapons.zip을 합친 4,573개 파일을 보관합니다.
medieval/sprites/weapons는 weapons.zip의 406개 PNG를 기준으로 합니다. axe_01.png는 이후 받은 axe_01.zip의 원본으로 교체했습니다.
.gdignore와 export 제외 설정으로 원본 전체를 게임에 직접 임포트하지 않습니다.

## 수정 및 교체

개별 PNG는 같은 경로에 저장한 뒤 `python tools/build_medieval_atlas.py` 또는 `bash tools/build-web.sh`를 실행합니다.
파일명은 그룹명_번호.png 형식이며 번호 결번도 지원합니다. 원본 이미지의 크기를 줄이지 않습니다.
무기 손잡이는 tools/build_medieval_atlas.py의 weapon_grip에서 설정합니다.

전체 ZIP: `python tools/import_medieval_assets.py /path/to/MedievalFantasyCharacters.zip`

무기 ZIP만: `python tools/import_medieval_assets.py /path/to/weapons.zip --weapons`

임시 폴더에서 검증 후 교체합니다. 삭제된 파일은 남기지 않으며 무기만 가져올 때 다른 원본은 유지합니다.

## 생성 결과

assets/medieval의 아틀라스와 catalog.json은 생성물이므로 직접 수정하지 않습니다.
현재 1,288개 파츠를 아틀라스 2장으로 묶고, 무기176종은 파일명 식별자로 연결합니다.
생성 화면은 axe_01, blunt_01, sword_01의 3종입니다.
spear는 찌르기, 다른 장착 무기는 휘두르기를 사용합니다. 발사체/발사 프레임은 장착 항목이 아닙니다.
세부 기준은 docs/character-design.md를 참고하세요.
