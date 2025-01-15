import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchLocation {
  final String displayName;
  final LatLng coordinates;

  SearchLocation({required this.displayName, required this.coordinates});
}

class NominatimService {
  static Future<List<SearchLocation>> searchLocation(String query, String languageCode) async {
    final String url = 
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&accept-language=$languageCode';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'Accept-Language': languageCode,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) {
        return SearchLocation(
          displayName: json['display_name'],
          coordinates: LatLng(
            double.parse(json['lat']),
            double.parse(json['lon']),
          ),
        );
      }).toList();
    }
    
    throw Exception('Failed to search location');
  }
} 