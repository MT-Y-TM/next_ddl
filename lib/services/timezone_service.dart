import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract class TimezoneService {
  Future<void> initialize();

  String get currentTimezoneId;

  tz.Location get location;

  List<String> get timezoneIds;

  DateTime localToUtc(DateTime value);

  DateTime utcToConfigured(DateTime value);

  Future<bool> setTimezone(String timezoneId);
}

class DeviceTimezoneService extends ChangeNotifier implements TimezoneService {
  DeviceTimezoneService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'app_timezone_id';
  static const fallbackTimezoneId = 'Asia/Shanghai';

  SharedPreferences? _preferences;
  late tz.Location _location;
  String _currentTimezoneId = fallbackTimezoneId;
  List<String> _timezoneIds = const [];

  @override
  String get currentTimezoneId => _currentTimezoneId;

  @override
  tz.Location get location => _location;

  @override
  List<String> get timezoneIds => _timezoneIds;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    _timezoneIds = tz.timeZoneDatabase.locations.keys.toList()..sort();
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    final detected = stored ?? await _detectDeviceTimezone();
    final timezoneId = _isKnownTimezone(detected)
        ? detected!
        : fallbackTimezoneId;
    _setLocation(timezoneId);
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

  @override
  DateTime utcToConfigured(DateTime value) {
    return tz.TZDateTime.from(value.toUtc(), _location);
  }

  @override
  Future<bool> setTimezone(String timezoneId) async {
    if (!_isKnownTimezone(timezoneId)) {
      return false;
    }
    if (timezoneId == _currentTimezoneId) {
      return true;
    }
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setString(storageKey, timezoneId);
    _setLocation(timezoneId);
    notifyListeners();
    return true;
  }

  Future<String?> _detectDeviceTimezone() async {
    try {
      return FlutterTimezone.getLocalTimezone();
    } catch (_) {
      return null;
    }
  }

  bool _isKnownTimezone(String? timezoneId) {
    return timezoneId != null &&
        tz.timeZoneDatabase.locations.containsKey(timezoneId);
  }

  void _setLocation(String timezoneId) {
    _currentTimezoneId = timezoneId;
    _location = tz.getLocation(timezoneId);
  }
}

final timezoneServiceProvider = Provider<DeviceTimezoneService>((ref) {
  throw UnimplementedError('timezoneServiceProvider must be overridden');
});
