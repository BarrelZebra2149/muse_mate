class PlaceModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? photoReference;
  final double rating;
  final List<String> types;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.photoReference,
    required this.rating,
    required this.types,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['place_id'] ?? '',
      name: json['name'] ?? '',
      address: json['vicinity'] ?? json['formatted_address'] ?? '',
      latitude: json['geometry']['location']['lat']?.toDouble() ?? 0.0,
      longitude: json['geometry']['location']['lng']?.toDouble() ?? 0.0,
      photoReference: json['photos']?.isNotEmpty == true
          ? json['photos'][0]['photo_reference']
          : null,
      rating: json['rating']?.toDouble() ?? 0.0,
      types: List<String>.from(json['types'] ?? []),
    );
  }
}