// 사진 등록 규칙 (사용자가 바꾸지 않는 값)
class PhotoRules {
  // 이 시간보다 오래전에 찍은 사진은 올릴 수 없다.
  // 실제 서비스라면 3시간, 수업에서는 미리 찍어 둔 사진도 쓰도록 2160시간(약 3개월)
  static const maxAgeHours = 2160;

  // 현재 위치에서 가장 가까운 도시까지 이 거리 안이어야 그 도시 사진으로 등록한다.
  static const maxDistanceKm = 40.0;

  // 이 시간 안에 찍은 최근 사진은 좋아요가 많은 순서로 앞에 보여 준다.
  static const popularWindowHours = 1;
}

// 홈 위쪽 보기 범위 칩: 이름과 기간 (S07에서 사용)
const viewRanges = <String, Duration>{
  '1시간': Duration(hours: 1),
  '3시간': Duration(hours: 3),
  '하루': Duration(days: 1),
  '1주': Duration(days: 7),
  '3개월': Duration(days: 90),
};
