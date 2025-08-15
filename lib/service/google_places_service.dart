import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/place_model.dart';

class GooglePlacesService {
  static String get _apiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  static Future<List<PlaceModel>> getNearbyPlaces({
    required LatLng location,
    double radius = 1000.0,
    String type = 'restaurant|cafe|bar|night_club',
  }) async {
    if (_apiKey.isEmpty) {
      print('Google Places API key not set');
      return [];
    }

    final url = '$_baseUrl/nearbysearch/json'
        '?location=${location.latitude},${location.longitude}'
        '&radius=${radius.toInt()}'
        '&type=$type'
        '&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      print('📡 Places API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        print('발견된 장소: ${results.length}개');

        return results
            .map((place) => PlaceModel.fromJson(place))
            .take(20)
            .toList();
      }
    } catch (e) {
      print('🚨 Places API 오류: $e');
    }

    return [];
  }

  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$_apiKey';
  }
}