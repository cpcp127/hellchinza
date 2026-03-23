class FeedPlace {
  final String title;
  final String address;
  final double lat;
  final double lng;

  const FeedPlace({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  factory FeedPlace.fromJson(Map<String, dynamic> json) {
    return FeedPlace(
      title: (json['title'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
