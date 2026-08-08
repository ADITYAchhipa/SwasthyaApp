/// Conditional import: uses dart:html on web, stub on Android/iOS.
export 'geolocation_web.dart'
    if (dart.library.io) 'geolocation_mobile.dart';
