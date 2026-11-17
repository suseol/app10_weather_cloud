import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../config/firebase_config.dart';
import '../config/photo_rules.dart';
import '../models/weather_models.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/photo_rule_service.dart';
import '../services/cloud_photo_service.dart';
import 'create_photo_page.dart';

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  Region _region = regions.first; // 처음 조회할 지역
  bool _nearHere = false; // _region이 현재 GPS 위치로 고른 도시인지
  WeatherInfo? _weather; // 제공: 조회 전에는 null
  bool _loading = false; // 제공: 조회 중 표시용 상태
  bool _openingCreatePage = false; // 화면 중복 열기 방지
  bool _uploading = false; // S03-③ 사진을 올리는 중인지
  int _photoIndex = 0; // 보고 있는 사진의 번호
  String? _uid; // S01 로그인 전에는 null
  final _cloud = CloudPhotoService(); // S01
  bool _labConnected = false; // S02 실습 서버 출입 등록이 끝났는지
  List<CloudPhoto> _cloudPhotos = []; // S05 클라우드에서 받은 이 지역 사진
  String _rangeLabel = '3시간'; // S07 보기 범위 (기본 3시간, 저장하지 않음)
  StreamSubscription<List<CloudPhoto>>? _photoSub; // S05 구독(끊을 때 필요)

  // S01 화면이 처음 만들어질 때 한 번 로그인
  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    try {
      final uid = await _cloud.signIn();
      if (!mounted) return;
      setState(() => _uid = uid);
      await _connectLab(uid); // S02 로그인 다음에 실습 서버 출입 등록
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인하지 못했어요. 인터넷 연결을 확인해 주세요.')),
      );
    }
  }

  // S02 실습 서버 출입 등록 (출입 코드는 LMS로 받은 firebase_config.dart에 있음)
  Future<void> _connectLab(String uid) async {
    try {
      if (!await _cloud.isMember(uid)) { // S02-④ 처음일 때만 등록
        await _cloud.registerMember(uid, labAccessCode);
      }
      if (!mounted) return;
      setState(() => _labConnected = true);
      _watchRegion(); // S05 멤버가 된 다음에 사진 목록 구독(규칙: 멤버만 읽기)
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실습 서버에 연결하지 못했어요. 출입 코드를 확인해 주세요.')),
      );
    }
  }

  // S05 지금 지역의 클라우드 사진을 구독한다. 바뀔 때마다 _cloudPhotos가 새로 채워짐
  void _watchRegion() {
    _photoSub?.cancel(); // 이전 구독은 끊기
    final since = DateTime.now().subtract(viewRanges[_rangeLabel]!); // S07 보기 범위 시작 시각
    _photoSub = _cloud.watchPhotos(_region.id, since).listen(
      (list) => setState(() => _cloudPhotos = list),
      onError: (e) => debugPrint('사진 목록 오류: $e'),
    );
  }

  // S06 좋아요 켜기/끄기. 화면은 구독(S05)이 새 목록을 받아 다시 그려 준다.
  Future<void> _toggleLike(CloudPhoto photo) async {
    if (_uid == null) return;
    try {
      await _cloud.setLiked(photo.id, _uid!, !photo.isLikedBy(_uid!));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요를 저장하지 못했어요.')),
      );
    }
  }

  @override
  void dispose() {
    _photoSub?.cancel(); // S05 화면이 사라지면 구독도 끊기
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() { _loading = true; _weather = null; });
    try {
      final result = await WeatherService().fetch(_region); // 지역 좌표로 조회
      if (!mounted) return; // 화면 종료 후 갱신 방지
      setState(() => _weather = result); // 결과 저장과 rebuild 요청
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날씨를 불러오지 못했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // lab10 제공: GPS 좌표 대신 가장 가까운 도시를 고른다.
  Future<void> _useCurrentLocation() async {
    try {
      final position = await LocationService().getCurrent(); // 기기 좌표
      final near = PhotoRuleService()
          .nearestRegion(position.latitude, position.longitude);
      if (!mounted) return;
      if (near == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지원하는 도시 근처에서만 사진을 등록할 수 있어요.')),
        );
        return;
      }
      setState(() {
        _region = near; // 'current' 대신 도시 목록의 지역을 사용
        _nearHere = true;
        _photoIndex = 0; // 지역 변경 후 첫 장
      });
      _watchRegion(); // S05-④ 바뀐 지역으로 다시 구독
      await _loadWeather(); // 기존 날씨 조회 재사용
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 위치를 확인하지 못했어요. 위치가 있어야 사진을 등록할 수 있어요.'),
        ),
      );
    }
  }

  Future<void> _openCreatePage() async {
    if (_openingCreatePage) return; // 연속 클릭은 무시
    _openingCreatePage = true;
    try {
      if (!_nearHere) { // 사진 위치는 항상 등록할 때의 GPS로 정한다.
        await _useCurrentLocation();
        if (!mounted || !_nearHere) return;
      }
      final record = await Navigator.push<WeatherRecord>(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePhotoPage(
            region: _region, weather: _weather,
          ),
        ),
      );
      if (record == null || !mounted) return; // 취소하면 결과 없음
      setState(() => _photoIndex = 0); // 새 사진 등록 후 첫 장 (S05-⑤ 목록은 구독으로 들어옴)
      await _uploadRecord(record); // S03 기기 사진을 클라우드에 올리기
    } finally {
      _openingCreatePage = false; // 돌아오면 다시 열기 허용
    }
  }

  // S03 기기에 있는 사진 파일을 Storage의 photos/{내 uid}/ 폴더에 올린다.
  Future<void> _uploadRecord(WeatherRecord record) async {
    if (_uid == null) return;
    final path = 'photos/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    setState(() => _uploading = true); // S03-③
    try {
      final url = await _cloud.uploadImage(path, File(record.imagePath));
      await _cloud.savePhoto(record.toMap( // S04 제공: 기록 → 문서 내용(Map)
        ownerUid: _uid!, imageUrl: url, storagePath: path,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 공유했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 올리지 못했어요.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false); // S03-③ 성공, 실패 모두 끝
    }
  }

  Future<void> _chooseRegion() async {
    final picked = await showModalBottomSheet<Region>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true, // 항목 수에 맞는 높이
          children: [
            for (final item in regions)
              ListTile(
                title: Text(item.name),
                onTap: () => Navigator.pop(sheetContext, item),
              ), // 선택한 Region을 결과로 전달
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return; // 선택 없이 닫으면 null
    setState(() {
      _region = picked;
      _nearHere = false; // 목록에서 고른 도시는 현재 위치가 아님
      _photoIndex = 0;
    });
    _watchRegion(); // S05-④ 바뀐 지역으로 다시 구독
    await _loadWeather(); // 선택 지역 날씨 재조회
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather; // State를 읽는 지역변수, 새 State가 아님
    final photos = _cloudPhotos; // S05-⑤ 기기 목록 대신 클라우드의 이 지역 사진
    final shownIndex = _photoIndex < photos.length ? _photoIndex : 0;
    final shownPhoto = photos.isEmpty ? null : photos[shownIndex];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: photos.isEmpty
                ? Image.asset(
                    weather?.backgroundAsset ??
                        'assets/images/weather/clear.jpg',
                    fit: BoxFit.cover,
                  )
                : PageView.builder(
                    key: ValueKey('${_region.id}-${photos.length}'),
                    itemCount: photos.length,
                    onPageChanged: (index) =>
                        setState(() => _photoIndex = index),
                    itemBuilder: (context, index) => Image.network( // S05-⑤
                      photos[index].imageUrl, fit: BoxFit.cover,
                    ),
                  ),
          ),
          const Positioned.fill(
            child: IgnorePointer( // 장식은 터치를 가로막지 않음
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x77000000),
                      Color(0x00000000),
                      Color(0xB8000000),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _chooseRegion,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        label: Text(_nearHere
                            ? '현재 위치 · ${_region.name} 근처'
                            : _region.name),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _useCurrentLocation,
                        color: Colors.white,
                        tooltip: '현재 위치',
                        icon: const Icon(Icons.my_location),
                      ),
                      IconButton(
                        onPressed: _loading ? null : _loadWeather,
                        color: Colors.white,
                        tooltip: '날씨 새로고침',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  Text( // S01 내 번호(uid 앞 6자리)
                    _uid == null
                        ? '로그인 중...'
                        : '내 번호: ${_uid!.substring(0, 6)} | '
                          '${_labConnected ? '실습 서버 연결됨' : '실습 서버 확인 중...'}' // S02
                          ' | 클라우드 사진 ${_cloudPhotos.length}장', // S05
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SingleChildScrollView( // S07 보기 범위 칩 한 줄 (기간 목록은 제공 viewRanges)
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final label in viewRanges.keys)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: label == _rangeLabel,
                              onSelected: (_) {
                                setState(() => _rangeLabel = label);
                                _watchRegion(); // S07-③ 바뀐 기간으로 다시 구독
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    weather == null
                        ? '--°' : '${weather.temperature.round()}°',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 86,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    weather?.condition ?? '새로고침을 눌러 주세요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                  ),
                  if (weather != null)
                    Text(
                      '습도 ${weather.humidity}%  |  '
                      '풍속 ${weather.windSpeed.round()}km/h',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (weather != null)
                    Text(
                      '기상 기준 ${weather.observedAt.hour.toString().padLeft(2, '0')}:'
                      '${weather.observedAt.minute.toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  if (_loading) const LinearProgressIndicator(),
                  const Spacer(),
                  if (shownPhoto != null && shownPhoto.description.isNotEmpty)
                    Text(
                      shownPhoto.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  if (shownPhoto != null && shownPhoto.description.isNotEmpty)
                    const SizedBox(height: 8),
                  if (shownPhoto != null) // S06 좋아요 버튼과 숫자
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _toggleLike(shownPhoto), // S06-③
                          icon: shownPhoto.isLikedBy(_uid ?? '') // 내가 눌렀으면 빨간 하트
                              ? const Icon(Icons.favorite, color: Colors.redAccent)
                              : const Icon(Icons.favorite_border, color: Colors.white),
                        ),
                        Text(
                          '${shownPhoto.likeCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  Text(
                    shownPhoto?.sourceLabel ?? '기본 날씨 배경 (현장 사진 없음)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (photos.length > 1)
                    Text(
                      '사진 ${shownIndex + 1} / ${photos.length}  |  좌우로 넘기기',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton(
                      onPressed: _uploading ? null : _openCreatePage, // S03-③ 올리는 중엔 막기
                      tooltip: '사진 등록',
                      child: _uploading
                          ? const CircularProgressIndicator() // S03-③
                          : const Icon(Icons.add_a_photo_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
