import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:location/location.dart' as loc;
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/kakao_rest_api_service.dart';
import '../../../home/domain/models/home_feed_post.dart';

class HandDrawnMapWidget extends StatefulWidget {
  final List<HomeFeedPost> posts;
  final Function(String postId, String title)? onPostMarkerTapped;
  final Function(double lat, double lng)? onMapTapped;
  final VoidCallback? onMapReady;
  final Function(String address, double lat, double lng)? onLocationChanged;

  const HandDrawnMapWidget({
    super.key,
    this.posts = const [],
    this.onPostMarkerTapped,
    this.onMapTapped,
    this.onMapReady,
    this.onLocationChanged,
  });

  @override
  State<HandDrawnMapWidget> createState() => _HandDrawnMapWidgetState();
}

class _HandDrawnMapWidgetState extends State<HandDrawnMapWidget> {
  KakaoMapController? _mapController;
  final loc.Location _location = loc.Location();
  LatLng _currentLocation = const LatLng(37.5665, 126.9780); // 기본값: 서울
  Poi? _userLocationPoi; // 사용자 위치 POI
  Timer? _locationUpdateTimer; // 위치 업데이트 타이머
  // Timer? _addressUpdateTimer; // 주소 업데이트 타이머 - 일시적 비활성화
  bool _isLocationReady = false; // 위치 준비 상태
  String _currentAddress = "위치 정보를 받아오는 중"; // 현재 주소

  @override
  void initState() {
    super.initState();
    _initializeLocationAndMap();
  }

  Future<void> _initializeLocationAndMap() async {
    debugPrint('=== 지도 초기화 시작 (안드로이드 GPS만) ===');

    // 안드로이드 GPS로 위치만 빠르게 가져와서 지도 로드
    await _getCurrentLocationForMapOnly();

    debugPrint('=== 지도 로딩 준비 완료 ===');

    // 지도 로딩 완료 후 위치 업데이트 타이머만 시작
    _startPeriodicLocationUpdate();

    debugPrint('=== 타이머 시작 완료 ===');
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicLocationUpdate() {
    // 1분마다 위치 업데이트 (안드로이드 GPS 사용)
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateLocationPeriodically();
    });
  }

  void _updateLocationPeriodically() async {
    try {
      // 1단계: 안드로이드 GPS로 위치 획득
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final newLocation = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        debugPrint(
          '🕐 주기적 GPS 위치 업데이트: ${newLocation.latitude.toStringAsFixed(4)}, ${newLocation.longitude.toStringAsFixed(4)}',
        );

        // GPS 위치 즉시 업데이트
        _updateUserLocationWithoutAddress(newLocation);

        // 2단계: 카카오 REST API로 한글 주소 획득
        _updateAddressFromKakao(newLocation);
      }
    } catch (e) {
      debugPrint('주기적 위치 업데이트 실패: $e');
    }
  }


  // 지도 로딩 전용 - 안드로이드 GPS만 사용 (카카오 API 없음)
  Future<void> _getCurrentLocationForMapOnly() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        // 위치 서비스 실패해도 기본 위치로 지도 로드
        setState(() {
          _isLocationReady = true;
        });
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        // 권한 실패해도 기본 위치로 지도 로드
        setState(() {
          _isLocationReady = true;
        });
        return;
      }
    }

    try {
      // 일회성 위치 획득을 위한 설정 (자동 업데이트 비활성화)
      await _location.changeSettings(
        accuracy: loc.LocationAccuracy.balanced,
        interval: 0, // 자동 업데이트 비활성화
        distanceFilter: 0, // 거리 필터 비활성화
      );

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng = LatLng(locationData.latitude!, locationData.longitude!);

        setState(() {
          _currentLocation = latLng;
          _isLocationReady = true; // 지도 로드 준비 완료
        });

        debugPrint(
          '지도 로딩용 위치 획득 완료 (안드로이드 GPS): ${locationData.latitude!.toStringAsFixed(4)}, ${locationData.longitude!.toStringAsFixed(4)}',
        );

        // 좌표 전달 및 백그라운드에서 한글 주소 업데이트
        widget.onLocationChanged?.call(
          _currentAddress,
          locationData.latitude!,
          locationData.longitude!,
        );

        // 초기 로딩 시 한글 주소 업데이트
        _updateAddressFromKakao(latLng);
      } else {
        // 위치 획득 실패시 기본 위치로 지도 로드
        setState(() {
          _isLocationReady = true;
        });
      }
    } catch (e) {
      debugPrint('위치 정보를 가져오는 중 오류 발생: $e');
      // 위치 획득 실패 시 기본 위치로 지도 로드
      setState(() {
        _isLocationReady = true;
      });
    }
  }

  // 카카오 REST API로 한글 주소 업데이트
  void _updateAddressFromKakao(LatLng location) async {
    try {
      debugPrint(
        '🏠 한글 주소 요청 중: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
      );

      final address = await KakaoRestApiService.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (mounted) {
        setState(() {
          _currentAddress = address;
        });

        debugPrint('🏠 한글 주소 업데이트: $address');

        // 상위 컴포넌트로 업데이트된 주소 전달
        widget.onLocationChanged?.call(
          _currentAddress,
          location.latitude,
          location.longitude,
        );
      }
    } catch (e) {
      debugPrint('❌ 한글 주소 변환 실패: $e');
      if (mounted) {
        setState(() {
          _currentAddress = '위치 정보 없음';
        });
      }
    }
  }

  Future<void> _createUserLocationPoi() async {
    if (_mapController == null || _userLocationPoi != null) return;

    try {
      debugPrint(
        'POI 생성 시도 - 위치: ${_currentLocation.latitude}, ${_currentLocation.longitude}',
      );

      // 커스텀 이미지 파일로 POI 생성 시도
      try {
        final imageFile = await _getImageFileFromAssets();
        debugPrint('이미지 파일 경로: ${imageFile.path}');

        final poiStyle = PoiStyle(
          icon: KImage.fromFile(imageFile, 40, 40),
          anchor: const KPoint(0.5, 0.5),
        );

        _userLocationPoi = await _mapController!.labelLayer.addPoi(
          _currentLocation,
          style: poiStyle,
        );

        debugPrint(
          '커스텀 POI 생성 성공: ${_currentLocation.latitude}, ${_currentLocation.longitude}',
        );
      } catch (e) {
        debugPrint('커스텀 POI 생성 실패: $e, 기본 POI로 시도...');

        // 기본 POI로 폴백
        _userLocationPoi = await _mapController!.labelLayer.addPoi(
          _currentLocation,
          style: PoiStyle(),
        );

        debugPrint('기본 POI 생성 성공');
      }
    } catch (e) {
      debugPrint('POI 생성 완전 실패: $e');
      debugPrint('에러 타입: ${e.runtimeType}');
      debugPrint('에러 메시지: ${e.toString()}');
    }
  }

  Future<File> _getImageFileFromAssets() async {
    // 애셋에서 이미지를 임시 파일로 복사
    final byteData = await rootBundle.load('assets/images/POI.png');
    final buffer = byteData.buffer;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/POI.png');

    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );

    return file;
  }

  // 주소 업데이트 없이 위치만 업데이트 (안드로이드 GPS 전용)
  void _updateUserLocationWithoutAddress(LatLng newLocation) async {
    if (_currentLocation.latitude != newLocation.latitude ||
        _currentLocation.longitude != newLocation.longitude) {
      setState(() {
        _currentLocation = newLocation;
      });

      // 사용자 위치 POI가 있으면 이동
      if (_userLocationPoi != null) {
        try {
          await _userLocationPoi!.move(newLocation);
          debugPrint(
            '사용자 위치 POI 이동됨 (안드로이드 GPS): ${newLocation.latitude}, ${newLocation.longitude}',
          );
        } catch (e) {
          debugPrint('사용자 위치 POI 이동 실패: $e');
        }
      }

      // 안드로이드 GPS 위치 정보 전달
      widget.onLocationChanged?.call(
        _currentAddress,
        newLocation.latitude,
        newLocation.longitude,
      );
    }
  }

  void _addMarkers() async {
    if (_mapController == null) return;
    // 마커 추가 기능 임시 비활성화
  }

  void moveToCurrentLocation() async {
    debugPrint('🔘 위치 버튼 클릭됨');

    // 저장된 현재 위치 사용 (GPS 재요청 없이)
    debugPrint(
      '📍 저장된 위치 사용: ${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}',
    );

    // POI 위치 확인 (이미 같은 위치일 수도 있음)
    if (_userLocationPoi != null) {
      debugPrint('🎯 POI 위치 업데이트');
      await _userLocationPoi!.move(_currentLocation);
    }

    // 2단계 카메라 이동: 이동(200ms) → 확대(100ms) 순차 실행
    if (_mapController != null) {
      debugPrint(
        '🎥 카메라 이동 시작 → ${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}',
      );

      try {
        // 1단계: 위치 이동 (200ms)
        debugPrint('📍 1단계: 위치 이동 중...');
        final centerUpdate = CameraUpdate.newCenterPosition(_currentLocation);
        await _mapController!.moveCamera(
          centerUpdate,
          animation: const CameraAnimation(200),
        );
        debugPrint('📍 1단계 완료: 위치 이동');
        await Future.delayed(const Duration(milliseconds: 300));
        // 2단계: 줌 확대 (100ms) - 순차적 실행
        debugPrint('🔍 2단계: 줌 레벨 16으로 확대 중...');
        final zoomUpdate = CameraUpdate.zoomTo(17);
        await _mapController!.moveCamera(
          zoomUpdate,
          animation: const CameraAnimation(100),
        );
        debugPrint('🔍 2단계 완료: 줌 확대');

        debugPrint('🎥 전체 카메라 동작 완료 (총 300ms)');
      } catch (e) {
        debugPrint('❌ 카메라 이동 실패: $e');
      }
    } else {
      debugPrint('❌ 맵 컨트롤러가 null');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 위치가 준비되지 않았으면 로딩 표시
    if (!_isLocationReady) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '위치 정보를 가져오는 중...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // 위치가 준비되면 지도 로드
    return KakaoMap(
      option: KakaoMapOption(
        position: _currentLocation,
        zoomLevel: 16,
        mapType: MapType.normal,
      ),
      onMapReady: (controller) {
        _mapController = controller;
        _addMarkers();

        // 지도가 준비되면 사용자 위치 POI 생성
        _createUserLocationPoi();


        widget.onMapReady?.call();
      },
    );
  }
}
