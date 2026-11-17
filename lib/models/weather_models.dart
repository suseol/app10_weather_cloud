import 'package:cloud_firestore/cloud_firestore.dart';

// 11주차에는 모델을 제공하고, 화면에서 객체를 생성해 사용한다.
class Region {
  final String id; // 앱 안에서 지역을 구분하는 값 (Firestore 조회 키)
  final String name; // 화면에 표시할 지역명
  final double latitude; // 날씨 조회와 거리 계산에 사용할 위도
  final double longitude; // 날씨 조회와 거리 계산에 사용할 경도

  const Region(this.id, this.name, this.latitude, this.longitude);
}

// 12주차: 사진을 함께 모으는 단위가 되는 도시 16곳 (좌표는 시청 부근)
const regions = <Region>[
  Region('seoul', '서울', 37.5665, 126.9780),
  Region('incheon', '인천', 37.4563, 126.7052),
  Region('suwon', '수원', 37.2636, 127.0286),
  Region('chuncheon', '춘천', 37.8813, 127.7298),
  Region('gangneung', '강릉', 37.7519, 128.8761),
  Region('cheongju', '청주', 36.6424, 127.4890),
  Region('cheonan', '천안', 36.8151, 127.1139),
  Region('daejeon', '대전', 36.3504, 127.3845),
  Region('jeonju', '전주', 35.8242, 127.1480),
  Region('gwangju', '광주', 35.1595, 126.8526),
  Region('daegu', '대구', 35.8714, 128.6014),
  Region('pohang', '포항', 36.0190, 129.3435),
  Region('ulsan', '울산', 35.5384, 129.3114),
  Region('busan', '부산', 35.1796, 129.0756),
  Region('changwon', '창원', 35.2280, 128.6811),
  Region('jeju', '제주', 33.4996, 126.5312),
];

class WeatherInfo {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final int weatherCode; // Open-Meteo의 숫자형 날씨 코드
  final DateTime observedAt; // 날씨 데이터의 기준 시각

  const WeatherInfo({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.observedAt,
  });

  // getter: weatherCode를 한국어 문구로 계산한다.
  String get condition {
    if (weatherCode >= 71 && weatherCode <= 77) return '눈';
    if (weatherCode >= 51 && weatherCode <= 67 ||
        weatherCode >= 80 && weatherCode <= 82 ||
        weatherCode >= 95) return '비';
    if (weatherCode >= 2) return '흐림';
    return '맑음';
  }

  // condition에 맞는 기본 배경 파일 경로를 고른다.
  String get backgroundAsset {
    if (condition == '눈') return 'assets/images/weather/snow.jpg';
    if (condition == '비') return 'assets/images/weather/rain.jpg';
    if (condition == '흐림') return 'assets/images/weather/cloudy.jpg';
    return 'assets/images/weather/clear.jpg';
  }
}

// 사진 아래에 표시할 문구: '카메라 2026/11/14 18:16'
String shotLabel(bool fromCamera, DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final source = fromCamera ? '카메라' : '갤러리';
  return '$source ${time.year}/${two(time.month)}/${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

// 등록 화면에서 만든 기록 (아직 기기 안에만 있음)
class WeatherRecord {
  final String regionId; // Region.id와 비교할 값
  final String imagePath; // 기기에 있는 이미지 파일 경로
  final String description; // AI 설명, 없으면 빈 문자열
  final bool fromCamera;
  final DateTime capturedAt; // 카메라는 지금, 갤러리는 EXIF 촬영 시각
  final DateTime createdAt; // 앱에 기록을 등록한 시각

  const WeatherRecord({
    required this.regionId,
    required this.imagePath,
    required this.description,
    required this.fromCamera,
    required this.capturedAt,
    required this.createdAt,
  });

  String get sourceLabel => shotLabel(fromCamera, capturedAt);

  // 12주차 제공: Firestore에 저장할 문서 내용(Map)으로 바꾼다.
  Map<String, dynamic> toMap({
    required String ownerUid,
    required String imageUrl,
    required String storagePath,
  }) {
    return {
      'ownerUid': ownerUid,
      'regionId': regionId,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'description': description,
      'fromCamera': fromCamera,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'createdAt': FieldValue.serverTimestamp(), // 서버가 시각을 채움
      'likedBy': <String>[], // 좋아요 0개로 시작 (보안 규칙 조건)
    };
  }
}

// 12주차 제공: Firestore에서 읽어 온 사진 한 장
class CloudPhoto {
  final String id; // Firestore 문서 ID
  final String ownerUid; // 올린 사람
  final String regionId;
  final String imageUrl; // Storage 다운로드 주소
  final String storagePath; // Storage 안의 파일 위치 (삭제할 때 사용)
  final String description;
  final bool fromCamera;
  final DateTime capturedAt;
  final List<String> likedBy; // 좋아요를 누른 사람들의 uid

  const CloudPhoto({
    required this.id,
    required this.ownerUid,
    required this.regionId,
    required this.imageUrl,
    required this.storagePath,
    required this.description,
    required this.fromCamera,
    required this.capturedAt,
    required this.likedBy,
  });

  // Firestore 문서 → CloudPhoto 객체
  factory CloudPhoto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CloudPhoto(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      regionId: data['regionId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      description: data['description'] as String? ?? '',
      fromCamera: data['fromCamera'] as bool? ?? false,
      capturedAt: (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
    );
  }

  int get likeCount => likedBy.length;
  bool isLikedBy(String uid) => likedBy.contains(uid);
  String get sourceLabel => shotLabel(fromCamera, capturedAt);
}
