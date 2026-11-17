import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/weather_models.dart';

// lab10: Firebase(로그인, Storage, Firestore)와 이야기하는 코드를 모은다.
class CloudPhotoService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance; // S02
  final _storage = FirebaseStorage.instance; // S03

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

  // S03 사진 파일을 Storage의 path 위치에 올리고, 사진을 열 수 있는 다운로드 주소를 받는다.
  Future<String> uploadImage(String path, File file) async {
    final ref = _storage.ref(path); // 버킷 안의 파일 위치
    // contentType: 올리는 파일에 붙이는 '종류 표시'다(제한이 아님).
    // 보안 규칙(storage.rules)이 이 표시가 image/로 시작하는지 검사한다.
    // 카메라 사진은 JPEG라 image/jpeg로 고정했다. 갤러리의 PNG도 올라가고 화면에도 잘 보인다(표시만 jpeg).
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  // S04 사진 정보를 photos 컬렉션에 새 문서로 저장한다(문서 ID는 자동).
  Future<void> savePhoto(Map<String, dynamic> data) async {
    await _db.collection('photos').add(data);
  }

  // S05 이 지역 사진을 최근 촬영 순으로, 바뀔 때마다 계속 받는다.
  Stream<List<CloudPhoto>> watchPhotos(String regionId) {
    return _db
        .collection('photos') // photos 컬렉션에서
        .where('regionId', isEqualTo: regionId) // 이 지역 문서만
        .orderBy('capturedAt', descending: true) // 최근 촬영 순
        .limit(50) // 최대 50개
        .snapshots() // 바뀔 때마다 결과 묶음(QuerySnapshot)이 계속 오는 Stream
        .map((snap) => // Stream의 map: 묶음이 올 때마다 바꾼다
            snap.docs.map(CloudPhoto.fromDoc).toList()); // List의 map: 문서 하나 → CloudPhoto 하나, 다시 List로
  }
}
