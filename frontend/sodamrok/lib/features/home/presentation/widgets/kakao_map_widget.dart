import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/models/home_feed_post.dart';

class KakaoMapWidget extends StatefulWidget {
  const KakaoMapWidget({
    super.key,
    this.posts = const [],
    this.onMapReady,
    this.onPostMarkerTapped,
    this.onMapTapped,
  });

  final List<HomeFeedPost> posts;
  final VoidCallback? onMapReady;
  final Function(String postId, String title)? onPostMarkerTapped;
  final Function(double lat, double lng)? onMapTapped;

  @override
  State<KakaoMapWidget> createState() => _KakaoMapWidgetState();
}

class _KakaoMapWidgetState extends State<KakaoMapWidget> {
  late final WebViewController _controller;
  final Location _location = Location();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _requestLocationPermission();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _loadMapHtml();
          },
        ),
      )
      ..addJavaScriptChannel(
        'mapMessage',
        onMessageReceived: _handleMapMessage,
      );
  }

  Future<void> _loadMapHtml() async {
    try {
      String htmlContent = await rootBundle.loadString('assets/kakao_map.html');

      // TODO: 실제 카카오 API 키로 교체 필요
      htmlContent = htmlContent.replaceAll(
        'YOUR_KAKAO_API_KEY',
        'YOUR_ACTUAL_KAKAO_API_KEY_HERE'
      );

      final String contentBase64 = base64Encode(const Utf8Encoder().convert(htmlContent));
      await _controller.loadRequest(
        Uri.parse('data:text/html;base64,$contentBase64'),
      );
    } catch (e) {
      debugPrint('카카오맵 로드 실패: $e');
    }
  }

  void _handleMapMessage(JavaScriptMessage message) {
    try {
      final Map<String, dynamic> data = json.decode(message.message);
      final String type = data['type'] ?? '';
      final dynamic messageData = data['data'];

      switch (type) {
        case 'mapReady':
          setState(() {
            _isMapReady = true;
          });
          widget.onMapReady?.call();
          _getCurrentLocation();
          _addPostMarkers();
          break;

        case 'mapClicked':
          if (messageData != null && widget.onMapTapped != null) {
            widget.onMapTapped!(
              messageData['lat']?.toDouble() ?? 0.0,
              messageData['lng']?.toDouble() ?? 0.0,
            );
          }
          break;

        case 'postMarkerClicked':
          if (messageData != null && widget.onPostMarkerTapped != null) {
            widget.onPostMarkerTapped!(
              messageData['id']?.toString() ?? '',
              messageData['title']?.toString() ?? '',
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('맵 메시지 처리 실패: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_isMapReady) return;

    try {
      final LocationData locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        await _controller.runJavaScript('''
          setCurrentLocation(${locationData.latitude}, ${locationData.longitude});
        ''');
      }
    } catch (e) {
      debugPrint('현재 위치 가져오기 실패: $e');
      // 기본 위치 (수원 팔달구) 사용
      await _controller.runJavaScript('''
        setCurrentLocation(37.2636, 127.0286);
      ''');
    }
  }

  Future<void> _addPostMarkers() async {
    if (!_isMapReady || widget.posts.isEmpty) return;

    for (final post in widget.posts) {
      // TODO: 실제 위치 데이터가 있다면 사용, 없으면 더미 좌표
      final lat = 37.2636 + (widget.posts.indexOf(post) * 0.01); // 더미 좌표
      final lng = 127.0286 + (widget.posts.indexOf(post) * 0.01);

      await _controller.runJavaScript('''
        addPostMarker('${post.id}', $lat, $lng, '${post.caption.replaceAll("'", "\\'")}');
      ''');
    }
  }

  Future<void> moveToLocation(double lat, double lng, {int? zoomLevel}) async {
    if (!_isMapReady) return;

    await _controller.runJavaScript('''
      moveToLocation($lat, $lng, ${zoomLevel ?? 'null'});
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_isMapReady)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFBACFCA),
                  Color(0xFF8EB4AC),
                  Color(0xFF5F938A),
                ],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '지도를 불러오는 중...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}