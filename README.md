# App10 | 지금 날씨 보여줘 (클라우드 공유)

12주차 실습 starter입니다. 11주차에 만든 "지금 날씨 보여줘"에 Firebase를 연결해, 같은 지역에서 찍은 날씨 사진을 친구들과 실시간으로 함께 보고 좋아요를 누르는 앱을 완성합니다.

## 준비

1. 영문 경로에 내려받습니다. 예: `C:\dev\app10` (한글이 들어간 경로에서는 Android 빌드가 실패합니다)
2. 폴더에서 다음을 실행합니다. `--org kr.ac.koreatech`를 꼭 넣어야 Firebase에 연결됩니다.

```bash
flutter create --platforms=android --org kr.ac.koreatech --project-name show_me_weather .
flutter pub get
flutter run
```

3. `test/widget_test.dart`는 지워도 됩니다.
4. 수업 중 안내에 따라 LMS에서 받은 `firebase_config.dart`를 `lib/config/` 폴더에 넣습니다.
   - 이 파일은 `.gitignore`에 들어 있어 GitHub에 올라가지 않습니다. 직접 커밋하지 마세요.

## 폴더 구성

| 경로 | 내용 |
|---|---|
| `lib/main.dart` | 앱 시작 |
| `lib/config/` | 사진 규칙(`photo_rules.dart`), Firebase 설정 예시 |
| `lib/models/weather_models.dart` | 도시 16곳, 날씨, 사진 기록(`WeatherRecord`), 클라우드 사진(`CloudPhoto`) |
| `lib/services/` | 날씨, 위치, AI 음성, 사진 규칙 검사 |
| `lib/screens/` | 홈 화면, 사진 등록 화면 |

## 에뮬레이터 준비

- 위치 정확도 창이 나오면 **Turn on**
- Extended controls → Location에서 위치를 천안 부근으로
- 카메라가 바로 꺼지면 Device Manager → 편집 → Camera Back을 **VirtualScene**으로
