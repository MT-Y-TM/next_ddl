import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alarm_audio_item.dart';

abstract class AlarmAudioPickerService {
  Future<List<AlarmAudioItem>> pickAudioItems();
}

class FilePickerAlarmAudioPickerService implements AlarmAudioPickerService {
  @override
  Future<List<AlarmAudioItem>> pickAudioItems() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) {
      return const [];
    }
    return [
      for (final file in result.files)
        if ((file.path ?? file.identifier)?.trim().isNotEmpty ?? false)
          AlarmAudioItem(
            id: DateTime.now().microsecondsSinceEpoch.toString() + file.name,
            displayName: file.name,
            uri: (file.path ?? file.identifier)!,
          ),
    ];
  }
}

final alarmAudioPickerServiceProvider =
    Provider<AlarmAudioPickerService>((ref) {
  throw UnimplementedError('alarmAudioPickerServiceProvider must be overridden');
});
