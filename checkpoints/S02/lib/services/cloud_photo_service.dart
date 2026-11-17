import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// lab10: Firebase(로그인, Storage, Firestore)와 이야기하는 코드를 모은다.
class CloudPhotoService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance; // S02

  // S01 익명 로그인: 이미 로그인했으면 그 사용자, 처음이면 서버가 새 uid를 발급
  Future<String> signIn() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    return user.uid;
  }

  // S02 실습 서버 출입 등록: labMembers 컬렉션에 '내 uid'를 문서 ID로 한 문서를 만든다.
  // Map의 키가 필드 이름, 값이 필드 값이 된다(필드를 미리 만들 필요 없음).
  // 출입 코드가 틀리면 보안 규칙이 거부해서 예외가 난다.
  Future<void> registerMember(String uid, String accessCode) async {
    await _db.collection('labMembers').doc(uid).set({
      'accessCode': accessCode, // 앱이 가진 출입 코드. 규칙이 config/lab의 정답과 비교
      'joinedAt': FieldValue.serverTimestamp(), // 등록 시각(폰 시계가 아니라 서버 시각)
    });
  }

  // S02-④ 이미 등록했는지: 내 labMembers 문서가 있는지 읽어 본다.
  Future<bool> isMember(String uid) async {
    // 문서가 없어도 null이 아니라 '없음'이라고 적힌 결과(DocumentSnapshot)가 온다.
    final doc = await _db.collection('labMembers').doc(uid).get();
    return doc.exists; // 있으면 true, 없으면 false(이때 doc.data()는 null)
  }
}
