import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract class TimezoneService {
  Future<void> initialize();

  String get currentTimezoneId;

  tz.Location get location;

  DateTime localToUtc(DateTime value);
}

class DeviceTimezoneService implements TimezoneService {
  late tz.Location _location;
  String _currentTimezoneId = 'UTC';

  @override
  String get currentTimezoneId => _currentTimezoneId;

  @override
  tz.Location get location => _location;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      _currentTimezoneId = await FlutterTimezone.getLocalTimezone();
      _location = tz.getLocation(_currentTimezoneId);
    } catch (_) {
      _currentTimezoneId = 'UTC';
      _location = tz.getLocation('UTC');
    }
  }

  @override
  DateTime localToUtc(DateTime value) {
    final local = tz.TZDateTime(
      _location,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
    return local.toUtc();
  }
}

final timezoneServiceProvider = Provider<TimezoneService>((ref) {
  throw UnimplementedError('timezoneServiceProvider must be overridden');
});
