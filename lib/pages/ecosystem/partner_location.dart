import 'package:geolocator/geolocator.dart';

class PartnerPosition {
  const PartnerPosition(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// One foreground reading. The caller must already know the partner is online
/// and assigned. This does not start a background tracker or a map.
Future<PartnerPosition?> readPartnerPosition() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    return null;
  }
  final position = await Geolocator.getCurrentPosition();
  return PartnerPosition(position.latitude, position.longitude);
}
