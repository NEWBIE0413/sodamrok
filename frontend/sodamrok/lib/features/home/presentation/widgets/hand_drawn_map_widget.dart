import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:location/location.dart' as loc;

import '../../../../core/services/kakao_rest_api_service.dart';
import '../../../home/domain/models/home_feed_post.dart';

class HandDrawnMapWidget extends StatefulWidget {
  final List<HomeFeedPost> posts;
  final Function(String postId, String title)? onPostMarkerTapped;
  final Function(double lat, double lng)? onMapTapped;
  final VoidCallback? onMapReady;

  const HandDrawnMapWidget({
    super.key,
    this.posts = const [],
    this.onPostMarkerTapped,
    this.onMapTapped,
    this.onMapReady,
  });

  @override
  State<HandDrawnMapWidget> createState() => _HandDrawnMapWidgetState();
}

class _HandDrawnMapWidgetState extends State<HandDrawnMapWidget> {
  KakaoMapController? _mapController;
  final loc.Location _location = loc.Location();
  LatLng _currentLocation = const LatLng(37.5665, 126.9780); // 기본값: 서울

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }

    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng = LatLng(locationData.latitude!, locationData.longitude!);

        setState(() {
          _currentLocation = latLng;
        });

        await _getAddressFromCoordinates(locationData.latitude!, locationData.longitude!);
      }
    } catch (e) {
      debugPrint('위치 정보를 가져오는 중 오류 발생: $e');
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final address = await KakaoRestApiService.getAddressFromCoordinates(lat, lng);
      if (mounted) {
        debugPrint('현재 주소: $address');
      }
    } catch (e) {
      debugPrint('주소 변환 실패: $e');
    }
  }

  void _addMarkers() async {
    if (_mapController == null) return;
    // 마커 추가 기능 임시 비활성화
  }


  @override
  Widget build(BuildContext context) {
    return KakaoMap(
      option: KakaoMapOption(
        position: _currentLocation,
        zoomLevel: 16,
        mapType: MapType.normal,
      ),
      onMapReady: (controller) {
        _mapController = controller;
        _addMarkers();
        widget.onMapReady?.call();
      },
    );
  }
}