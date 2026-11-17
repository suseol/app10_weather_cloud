import 'dart:io';

import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';

import '../config/photo_rules.dart';
import '../models/weather_models.dart';

// lab10 제공 코드: 사진 시각과 위치를 규칙에 맞는지 검사한다.
class PhotoRuleService {
  // 갤러리 사진의 촬영 시각(EXIF DateTimeOriginal). 없으면 null
  Future<DateTime?> readCapturedAt(File file) async {
    final tags = await readExifFromBytes(await file.readAsBytes());
    final text = tags['EXIF DateTimeOriginal']?.printable; // '2026:11:14 18:16:01'
    if (text == null || text.length < 19) return null;
    // '2026:11:14 18:16:01' → '2026-11-14T18:16:01' (기기 시간대 기준)
    final iso = '${text.substring(0, 10).replaceAll(':', '-')}T${text.substring(11, 19)}';
    return DateTime.tryParse(iso);
  }

  // 등록할 수 없는 시각이면 이유를, 괜찮으면 null을 돌려준다.
  String? checkCapturedAt(DateTime? capturedAt) {
    if (capturedAt == null) {
      return '촬영 시각 정보가 없는 사진은 올릴 수 없어요.';
    }
    final hours = DateTime.now().difference(capturedAt).inHours;
    if (hours > PhotoRules.maxAgeHours) {
      return '${PhotoRules.maxAgeHours}시간 안에 찍은 사진만 올릴 수 있어요.';
    }
    return null;
  }

  // GPS 좌표에서 가장 가까운 도시. 기준 거리보다 멀면 null
  Region? nearestRegion(double latitude, double longitude) {
    Region? best;
    var bestKm = double.infinity;
    for (final region in regions) {
      final km = Geolocator.distanceBetween(
            latitude, longitude, region.latitude, region.longitude,
          ) / 1000;
      if (km < bestKm) {
        best = region;
        bestKm = km;
      }
    }
    return bestKm <= PhotoRules.maxDistanceKm ? best : null;
  }

  // 화면에 보여 줄 순서 (S08 선택 기능에서 사용)
  // 최근 사진(popularWindowHours 안)은 좋아요 많은 순으로 앞에, 나머지는 촬영 시각 최신 순.
  // Firestore는 배열 길이(좋아요 수)로 정렬할 수 없어서 받은 목록을 앱에서 다시 정렬한다.
  List<CloudPhoto> sortForDisplay(List<CloudPhoto> photos) {
    final from = DateTime.now()
        .subtract(const Duration(hours: PhotoRules.popularWindowHours));
    bool isRecent(CloudPhoto p) => p.capturedAt.isAfter(from);
    final sorted = [...photos]; // 원본 목록은 그대로 두고 복사본을 정렬
    sorted.sort((a, b) {
      if (isRecent(a) != isRecent(b)) return isRecent(a) ? -1 : 1; // 최근 사진 먼저
      if (isRecent(a) && a.likeCount != b.likeCount) {
        return b.likeCount.compareTo(a.likeCount); // 최근 사진끼리는 좋아요 많은 순
      }
      return b.capturedAt.compareTo(a.capturedAt); // 그다음은 촬영 시각 최신 순
    });
    return sorted;
  }
}
