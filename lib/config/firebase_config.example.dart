// Firebase 연결 설정값 예시 (저장소에는 이 파일만 올림)
//
// 1. LMS에서 firebase_config.dart 파일을 받는다.
// 2. 이 파일과 같은 폴더(lib/config/)에 넣는다.
// 3. firebase_config.dart 는 .gitignore에 있어 GitHub에 올라가지 않는다.
//
// 값은 Firebase 콘솔 → 프로젝트 설정 → 내 앱에서 확인할 수 있다.
import 'package:firebase_core/firebase_core.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'PASTE_API_KEY',
  appId: 'PASTE_APP_ID',
  messagingSenderId: 'PASTE_PROJECT_NUMBER',
  projectId: 'PASTE_PROJECT_ID',
  storageBucket: 'PASTE_BUCKET',
);

// 실습 서버 출입 코드: 교수 Firebase를 실습 참가자만 쓰도록 하는 비밀번호
// 상용 앱이라면 회원가입 + App Check로 대신한다.
const labAccessCode = 'PASTE_LAB_ACCESS_CODE';
