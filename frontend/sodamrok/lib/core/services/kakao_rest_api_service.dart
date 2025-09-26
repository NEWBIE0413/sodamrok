import 'dart:convert';
import 'package:http/http.dart' as http;

class KakaoRestApiService {
  static const String _baseUrl = 'https://dapi.kakao.com';
  static const String _apiKey = '1b81234a7250834aca9d925309fbd7a4'; // REST API 키

  static const Map<String, String> _headers = {
    'Authorization': 'KakaoAK $_apiKey',
    'Content-Type': 'application/json',
  };

  /// 좌표로 주소 검색 (좌표 → 주소)
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/v2/local/geo/coord2address.json?x=$longitude&y=$latitude',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List<dynamic>;

        if (documents.isNotEmpty) {
          final document = documents[0];
          final roadAddress = document['road_address'];
          final address = document['address'];

          // 도로명 주소가 있으면 우선 사용, 없으면 지번 주소 사용
          if (roadAddress != null) {
            return _formatRoadAddress(roadAddress);
          } else if (address != null) {
            return _formatAddress(address);
          }
        }
      } else {
        throw Exception('카카오 API 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('주소 변환 실패: $e');
    }

    return '주소를 찾을 수 없습니다';
  }

  /// 키워드로 장소 검색
  static Future<List<KakaoPlace>> searchPlaces(
    String keyword, {
    double? latitude,
    double? longitude,
    int radius = 5000,
    int size = 15,
  }) async {
    try {
      var url = '$_baseUrl/v2/local/search/keyword.json?query=${Uri.encodeComponent(keyword)}&size=$size';

      // 현재 위치가 있으면 위치 기반 검색
      if (latitude != null && longitude != null) {
        url += '&x=$longitude&y=$latitude&radius=$radius';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List<dynamic>;

        return documents
            .map((doc) => KakaoPlace.fromJson(doc))
            .toList();
      } else {
        throw Exception('카카오 API 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('장소 검색 실패: $e');
    }
  }

  /// 주소로 좌표 검색 (주소 → 좌표)
  static Future<KakaoCoordinate?> getCoordinatesFromAddress(String address) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/v2/local/search/address.json?query=${Uri.encodeComponent(address)}',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List<dynamic>;

        if (documents.isNotEmpty) {
          final document = documents[0];
          return KakaoCoordinate(
            latitude: double.parse(document['y']),
            longitude: double.parse(document['x']),
          );
        }
      } else {
        throw Exception('카카오 API 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('좌표 변환 실패: $e');
    }

    return null;
  }

  static String _formatRoadAddress(Map<String, dynamic> roadAddress) {
    final components = <String>[];

    if (roadAddress['region_1depth_name'] != null) {
      components.add(roadAddress['region_1depth_name']);
    }
    if (roadAddress['region_2depth_name'] != null) {
      components.add(roadAddress['region_2depth_name']);
    }
    if (roadAddress['region_3depth_name'] != null) {
      components.add(roadAddress['region_3depth_name']);
    }

    return components.isNotEmpty ? components.join(' ') : '주소 정보 없음';
  }

  static String _formatAddress(Map<String, dynamic> address) {
    final components = <String>[];

    if (address['region_1depth_name'] != null) {
      components.add(address['region_1depth_name']);
    }
    if (address['region_2depth_name'] != null) {
      components.add(address['region_2depth_name']);
    }
    if (address['region_3depth_name'] != null) {
      components.add(address['region_3depth_name']);
    }

    return components.isNotEmpty ? components.join(' ') : '주소 정보 없음';
  }
}

class KakaoPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String categoryName;
  final String? phone;
  final String addressName;
  final String? roadAddressName;
  final String? placeUrl;

  KakaoPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.categoryName,
    this.phone,
    required this.addressName,
    this.roadAddressName,
    this.placeUrl,
  });

  factory KakaoPlace.fromJson(Map<String, dynamic> json) {
    return KakaoPlace(
      id: json['id'] ?? '',
      name: json['place_name'] ?? '',
      latitude: double.parse(json['y'] ?? '0'),
      longitude: double.parse(json['x'] ?? '0'),
      categoryName: json['category_name'] ?? '',
      phone: json['phone']?.isEmpty == true ? null : json['phone'],
      addressName: json['address_name'] ?? '',
      roadAddressName: json['road_address_name']?.isEmpty == true
          ? null
          : json['road_address_name'],
      placeUrl: json['place_url']?.isEmpty == true ? null : json['place_url'],
    );
  }
}

class KakaoCoordinate {
  final double latitude;
  final double longitude;

  KakaoCoordinate({
    required this.latitude,
    required this.longitude,
  });
}