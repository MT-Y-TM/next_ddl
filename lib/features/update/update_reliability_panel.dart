import 'package:flutter/material.dart';
import '../../services/app_update_service.dart';
import 'app_update_state.dart';

class UpdateReliabilityLocalizations {
  const UpdateReliabilityLocalizations(this.languageCode);
  final String languageCode;
  String text(String zh, String en, String ja) => languageCode == 'zh'
      ? zh
      : languageCode == 'ja'
      ? ja
      : en;
  String get source => text(
    '通过 GitHub Release 资产 digest 或发布流水线的 SHA-256 校验文件验证完整性；这不替代 Android 签名验证。',
    'Integrity is checked against the GitHub Release asset digest or the release pipeline SHA-256 file; Android signature verification still applies.',
    'GitHub Release の digest またはリリース処理の SHA-256 ファイルで整合性を検証します。Android の署名検証を代替しません。',
  );
  String get releasePage => text('打开发布页', 'Open release page', 'リリースページを開く');
  String get retry => text('重试更新', 'Retry update', '更新を再試行');
  String failure(UpdateFailureReason reason) => switch (reason) {
    UpdateFailureReason.missingChecksum => text(
      '此旧版本未提供有效 SHA-256 校验信息，无法安全自动安装。请打开发布页或等待维护者补充校验文件。',
      'This release has no valid SHA-256 checksum, so automatic installation is blocked. Open the release page or wait for checksum metadata.',
      'このリリースには有効な SHA-256 がないため、自動インストールできません。リリースページを開くか、検証情報の追加をお待ちください。',
    ),
    UpdateFailureReason.integrityMismatch => text(
      '更新包或校验文件不完整或不匹配。未安装，请重试下载。',
      'The package or checksum file is incomplete or mismatched. Nothing was installed. Retry the download.',
      'パッケージまたは検証ファイルが不完全、または一致しません。インストールしていません。再ダウンロードしてください。',
    ),
    UpdateFailureReason.timeout => text(
      '网络超时，请检查连接后重试。',
      'Network timeout. Check your connection and retry.',
      '通信がタイムアウトしました。接続を確認して再試行してください。',
    ),
    UpdateFailureReason.busy => text(
      '更新操作进行中，请稍候。',
      'An update operation is in progress. Please wait.',
      '更新処理中です。お待ちください。',
    ),
    UpdateFailureReason.invalidCache => text(
      '安装缓存已失效，请重新下载。',
      'The installer cache is invalid. Download it again.',
      'インストーラーのキャッシュが無効です。再ダウンロードしてください。',
    ),
  };
}

/// Mount alongside the existing update card; no shared ARB changes required.
class UpdateReliabilityPanel extends StatelessWidget {
  const UpdateReliabilityPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onOpenRelease,
  });
  final AppUpdateState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenRelease;
  @override
  Widget build(BuildContext context) {
    final l = UpdateReliabilityLocalizations(
      Localizations.localeOf(context).languageCode,
    );
    final missing = state.release != null && !state.release!.hasChecksumSource;
    final reason =
        state.error?.reason ??
        (missing ? UpdateFailureReason.missingChecksum : null);
    final busy =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.checking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.source),
        if (reason != null) Text(l.failure(reason)),
        if (state.release != null)
          Wrap(
            spacing: 8,
            children: [
              if (!missing && state.status == AppUpdateStatus.error)
                TextButton(
                  onPressed: busy ? null : onRetry,
                  child: Text(l.retry),
                ),
              TextButton(
                onPressed: busy ? null : onOpenRelease,
                child: Text(l.releasePage),
              ),
            ],
          ),
      ],
    );
  }
}
