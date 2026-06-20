import 'package:flutter/material.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../../utils/timezone_labels.dart';

class TimezonePickerDialog extends StatefulWidget {
  const TimezonePickerDialog({
    required this.currentTimezoneId,
    required this.timezoneIds,
    super.key,
  });

  final String currentTimezoneId;
  final List<String> timezoneIds;

  @override
  State<TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<TimezonePickerDialog> {
  static const _commonTimezoneIds = [
    'Asia/Shanghai',
    'Asia/Hong_Kong',
    'Asia/Taipei',
    'Asia/Tokyo',
    'Asia/Seoul',
    'UTC',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _filteredTimezoneIds();
    return AlertDialog(
      title: Text(l10n.chooseTimezone),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.searchTimezone,
                hintText: l10n.searchTimezoneHint,
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final timezoneId = items[index];
                  final selected = timezoneId == widget.currentTimezoneId;
                  return ListTile(
                    dense: true,
                    leading: selected
                        ? const Icon(Icons.check)
                        : const SizedBox(width: 24),
                    title: Text(localizedTimezoneDisplayName(l10n, timezoneId)),
                    subtitle: Text(timezoneId),
                    onTap: () => Navigator.of(context).pop(timezoneId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  List<String> _filteredTimezoneIds() {
    final l10n = AppLocalizations.of(context)!;
    final known = widget.timezoneIds.toSet();
    final common = [
      for (final timezoneId in _commonTimezoneIds)
        if (known.contains(timezoneId)) timezoneId,
    ];
    final rest = [
      for (final timezoneId in widget.timezoneIds)
        if (!common.contains(timezoneId)) timezoneId,
    ];
    final ordered = [...common, ...rest];
    if (_query.isEmpty) {
      return ordered;
    }
    return [
      for (final timezoneId in ordered)
        if (timezoneId.toLowerCase().contains(_query) ||
            localizedTimezoneDisplayName(
              l10n,
              timezoneId,
            ).toLowerCase().contains(_query))
          timezoneId,
    ];
  }
}
