import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/difficulty.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import '../utils/logic_rate.dart';
import 'widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget picker(String label, List<Widget> chips) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          SectionCard(
            title: '外观',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('深色模式'),
              subtitle: const Text('夜间行军时更护眼'),
              value: settings.darkMode,
              onChanged: settings.setDarkMode,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '音频与触感',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('音效'),
                  subtitle: const Text('战鼓、号角与提示音，运行时合成'),
                  value: settings.soundEnabled,
                  onChanged: settings.setSoundEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('背景音乐'),
                  subtitle: const Text('古筝五声音阶循环'),
                  value: settings.musicEnabled,
                  onChanged: settings.setMusicEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('震动反馈'),
                  subtitle: const Text('移动端点击与战况震动'),
                  value: settings.hapticsEnabled,
                  onChanged: settings.setHapticsEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '对局节奏',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                picker('地图动画与选中脉冲的逻辑刷新率（对局中即时生效）', [
                  for (final rate in LogicRate.values)
                    ChoiceChip(
                      label: Text(rate.label),
                      selected: settings.logicRate == rate,
                      onSelected: (_) => settings.setLogicRate(rate),
                    ),
                ]),
                const SizedBox(height: 14),
                picker('默认难度（开局时可再选择）', [
                  for (final difficulty in Difficulty.values)
                    ChoiceChip(
                      label: Text(
                        '${difficulty.label} ${'★' * difficulty.stars}',
                      ),
                      selected: settings.difficulty == difficulty,
                      onSelected: (_) => settings.setDifficulty(difficulty),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _LogSection(),
          const SizedBox(height: 12),
          SectionCard(
            title: '关于',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppConstants.appName} v${AppConstants.version}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '回合制三国争霸，支持 Android、Windows 与 Web。'
                  '全部内容在本地运行，不联网、不收集数据。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection();

  Future<void> _openLogs(BuildContext context) async {
    final lines = LogService.getRecentLogs(300);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('最近日志'),
        content: SizedBox(
          width: 620,
          height: 420,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
                lines.isEmpty ? '暂无日志' : lines.join('\n'),
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectory(BuildContext context) async {
    final path = await FileSystemService.instance.getLogRootPath();
    if (path.isEmpty) return;
    final opened = await FileSystemService.instance.openDirectory(path);
    if (!context.mounted) return;
    if (!opened) showToast(context, '日志目录：$path');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final path = LogService.logFilePath;
    return SectionCard(
      title: '日志',
      trailing: TextButton(
        onPressed: () => _openLogs(context),
        child: const Text('查看'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            path.isEmpty ? 'Web 端仅保留内存日志' : path,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _openDirectory(context),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: const Text('打开日志目录'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  final text = LogService.getRecentLogs(80).join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  showToast(context, '最近 80 条日志已复制');
                },
                icon: const Icon(Icons.copy_all_outlined, size: 17),
                label: const Text('复制日志'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '日志按天写入用户目录，保留最近 7 天，单个文件超过 5 MB 自动轮转。',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
