import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../providers/device_model_label_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/post_signature.dart';
import 'settings_section_header.dart';

class PostSignatureSettingsSection extends ConsumerStatefulWidget {
  const PostSignatureSettingsSection({super.key});

  @override
  ConsumerState<PostSignatureSettingsSection> createState() =>
      _PostSignatureSettingsSectionState();
}

class _PostSignatureSettingsSectionState
    extends ConsumerState<PostSignatureSettingsSection> {
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(
      text: ref.read(settingsProvider).postSignatureCustom,
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final deviceAsync = ref.watch(deviceModelLabelProvider);
    final deviceLabel = deviceAsync.asData?.value ?? deviceModelLabelFallback();

    final display = PostSignature.buildDisplay(
      enabled: settings.postSignatureEnabled,
      showDevice: settings.postSignatureShowDevice,
      custom: settings.postSignatureCustom,
      deviceLabel: deviceLabel,
    );

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(title: '发帖小尾巴'),
              const SizedBox(height: 8),
              SwitchListTile(
                secondary: Icon(
                  Icons.edit_note_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                title: const Text('启用小尾巴'),
                subtitle: Text(
                  '发帖与回复提交时追加；编辑帖子不加。',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                value: settings.postSignatureEnabled,
                onChanged: notifier.setPostSignatureEnabled,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: const RoundedRectangleBorder(
                  borderRadius: S1Shape.small,
                ),
              ),
              SwitchListTile(
                secondary: Icon(
                  Icons.smartphone_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                title: const Text('显示机型'),
                subtitle: Text(
                  '自动读取设备型号；可关闭。',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                value: settings.postSignatureShowDevice,
                onChanged: settings.postSignatureEnabled
                    ? notifier.setPostSignatureShowDevice
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: const RoundedRectangleBorder(
                  borderRadius: S1Shape.small,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: TextField(
                  controller: _customController,
                  enabled: settings.postSignatureEnabled,
                  maxLength: PostSignature.maxCustomLength,
                  decoration: const InputDecoration(
                    labelText: '自定义前缀',
                    hintText: '可选，如「今日宜摸鱼」',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: notifier.setPostSignatureCustom,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('预览', style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: S1Shape.small,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: settings.postSignatureEnabled
                          ? _SignaturePreviewRich(
                              display: display,
                              appName: S1Constants.appName,
                              scheme: scheme,
                              textTheme: textTheme,
                            )
                          : Text(
                              '（已关闭）',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 论坛观感预览：「S1er 客户端」用链接色，不展示原始 BBCode。
class _SignaturePreviewRich extends StatelessWidget {
  const _SignaturePreviewRich({
    required this.display,
    required this.appName,
    required this.scheme,
    required this.textTheme,
  });

  final String display;
  final String appName;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final clientLabel = '$appName 客户端';
    final linkStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );
    final plainStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final index = display.lastIndexOf(clientLabel);
    if (index < 0) {
      return Text(display, style: plainStyle);
    }

    return Text.rich(
      TextSpan(
        style: plainStyle,
        children: [
          TextSpan(text: display.substring(0, index)),
          TextSpan(text: clientLabel, style: linkStyle),
          TextSpan(text: display.substring(index + clientLabel.length)),
        ],
      ),
    );
  }
}
