import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../data/database.dart';
import '../../providers/providers.dart';
import '../../providers/locale_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final scanRootsAsync = ref.watch(scanRootsProvider);

    return scanRootsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settingsTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settingsTitle),
        ),
        body: Center(child: Text('Error: $error')),
      ),
      data: (scanRoots) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settingsTitle),
        ),
        body: ListView(
          children: [
            _buildScanRootsSection(context, scanRoots),
            const Divider(),
            _buildWhitelistSection(context),
            const Divider(),
            _buildLanguageSection(context),
            const Divider(),
            _buildDangerZoneSection(context),
            const Divider(),
            _buildAboutSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildScanRootsSection(
    BuildContext context,
    List<ScanRoot> scanRoots,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.settingsScanRootDirectories,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...scanRoots.map(
          (root) => Dismissible(
            key: Key('scan_root_${root.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    AppLocalizations.of(context)!.settingsDeleteScanRoot,
                  ),
                  content: Text(
                    AppLocalizations.of(
                      context,
                    )!.settingsDeleteScanRootConfirm(root.path),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context)!.dialogCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(AppLocalizations.of(context)!.dialogDelete),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              await ref.read(scanRootServiceProvider).deleteScanRoot(root.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.settingsRemovedPath(root.path),
                    ),
                  ),
                );
              }
            },
            child: SwitchListTile(
              title: Text(root.path),
              subtitle: Text(
                root.enabled
                    ? AppLocalizations.of(context)!.settingsEnabled
                    : AppLocalizations.of(context)!.settingsDisabled,
              ),
              value: root.enabled,
              onChanged: (value) {
                ref
                    .read(scanRootServiceProvider)
                    .toggleScanRoot(root.id, enabled: value);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: FilledButton.tonalIcon(
            onPressed: () => _showAddScanRootDialog(context),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.settingsAddScanRoot),
          ),
        ),
      ],
    );
  }

  Widget _buildWhitelistSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.settingsWhitelistManagement,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: Text(AppLocalizations.of(context)!.settingsExportWhitelist),
          subtitle: Text(AppLocalizations.of(context)!.settingsExportSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _exportWhitelist(context),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(AppLocalizations.of(context)!.settingsImportWhitelist),
          subtitle: Text(AppLocalizations.of(context)!.settingsImportSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _importWhitelist(context),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.settingsPreferences,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(AppLocalizations.of(context)!.settingsLanguage),
          subtitle: Text(_getLanguageDisplayName(ref)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context),
        ),
      ],
    );
  }

  Widget _buildDangerZoneSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.settingsDangerZone,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            AppLocalizations.of(context)!.settingsClearAllData,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.settingsClearAllDataSubtitle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showClearDataDialog(context),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)!.settingsAbout,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text(AppLocalizations.of(context)!.settingsAboutApp),
          subtitle: Text(AppLocalizations.of(context)!.settingsVersionNumber),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            AppLocalizations.of(context)!.settingsAboutDescription,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _getLanguageDisplayName(WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    if (locale == null)
      return AppLocalizations.of(context)!.settingsLanguageSystem;
    switch (locale.languageCode) {
      case 'en':
        return AppLocalizations.of(context)!.settingsLanguageEnglish;
      case 'zh':
        if (locale.countryCode == 'TW') {
          return AppLocalizations.of(context)!.settingsLanguageTraditionalChinese;
        }
        return AppLocalizations.of(context)!.settingsLanguageChinese;
      default:
        return AppLocalizations.of(context)!.settingsLanguageSystem;
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final currentLocale = ref.read(localeProvider);
    var selectedLanguage = currentLocale == null
        ? 'system'
        : currentLocale.countryCode != null
            ? '${currentLocale.languageCode}_${currentLocale.countryCode}'
            : currentLocale.languageCode;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.settingsSelectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(
                  AppLocalizations.of(context)!.settingsLanguageSystem,
                ),
                value: 'system',
                groupValue: selectedLanguage,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedLanguage = value);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  AppLocalizations.of(context)!.settingsLanguageEnglish,
                ),
                value: 'en',
                groupValue: selectedLanguage,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedLanguage = value);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  AppLocalizations.of(context)!.settingsLanguageChinese,
                ),
                value: 'zh_CN',
                groupValue: selectedLanguage,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedLanguage = value);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  AppLocalizations.of(context)!.settingsLanguageTraditionalChinese,
                ),
                value: 'zh_TW',
                groupValue: selectedLanguage,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedLanguage = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.dialogCancel),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedLanguage == 'system') {
                  await ref.read(localeProvider.notifier).clearLocale();
                } else if (selectedLanguage.contains('_')) {
                  final parts = selectedLanguage.split('_');
                  await ref
                      .read(localeProvider.notifier)
                      .setLocale(parts[0], parts[1]);
                } else {
                  await ref
                      .read(localeProvider.notifier)
                      .setLocale(selectedLanguage);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(AppLocalizations.of(context)!.settingsOk),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.settingsClearAllData),
        content: Text(AppLocalizations.of(context)!.settingsClearDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.dialogCancel),
          ),
          FilledButton(
            onPressed: () => _clearAllData(context),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.settingsDeleteAll),
          ),
        ],
      ),
    );
  }

  void _showAddScanRootDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.settingsAddScanRootTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.settingsDirectoryPath,
            hintText: AppLocalizations.of(context)!.settingsDirectoryPathHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.dialogCancel),
          ),
          FilledButton(
            onPressed: () async {
              final path = controller.text.trim();
              if (path.isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(scanRootServiceProvider).addScanRoot(path);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.settingsAddedScanRoot(path),
                      ),
                    ),
                  );
                }
              } on ArgumentError catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.whitelistAddItem),
          ),
        ],
      ),
    );
  }

  Future<void> _exportWhitelist(BuildContext context) async {
    try {
      // Generate JSON first
      final json = await ref.read(exportImportServiceProvider).exportToJson();
      
      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile platforms, pass bytes directly to saveFile()
        final bytes = Uint8List.fromList(utf8.encode(json));
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Whitelist',
          fileName: 'whitelist.json',
          bytes: bytes,
        );
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.settingsExportSuccess,
              ),
            ),
          );
        }
      } else {
        // On desktop platforms, get path and write file
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Whitelist',
          fileName: 'whitelist.json',
        );
        if (result != null) {
          await ref.read(exportImportServiceProvider).exportToFile(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.settingsExportSuccess,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.settingsExportFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importWhitelist(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        // Check if there's existing data
        final items = await ref.read(whitelistServiceProvider).getAllItems();
        final groups = await ref.read(groupServiceProvider).getRootGroups();
        final scanRoots = await ref.read(scanRootServiceProvider).getAllScanRoots();
        
        final hasExistingData = items.isNotEmpty || groups.isNotEmpty || scanRoots.isNotEmpty;
        
        bool shouldReplace = false;
        
        if (hasExistingData && mounted) {
          // Show conflict dialog
          final action = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.settingsImportConflictTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.settingsImportConflictMessage),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep),
                    title: Text(AppLocalizations.of(context)!.settingsImportReplace),
                    subtitle: Text(AppLocalizations.of(context)!.settingsImportReplaceSubtitle),
                    onTap: () => Navigator.pop(context, 'replace'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.merge),
                    title: Text(AppLocalizations.of(context)!.settingsImportMerge),
                    subtitle: Text(AppLocalizations.of(context)!.settingsImportMergeSubtitle),
                    onTap: () => Navigator.pop(context, 'merge'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.dialogCancel),
                ),
              ],
            ),
          );
          
          if (action == null) return; // User cancelled
          shouldReplace = action == 'replace';
        }
        final filePath = result.files.single.path;
        if (filePath == null) {
          throw Exception('File path is null');
        }
        await ref
            .read(exportImportServiceProvider)
            .importFromFile(filePath, replace: shouldReplace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.settingsImportSuccess,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.settingsImportFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    Navigator.pop(context);
    try {
      final scanRoots = await ref
          .read(scanRootServiceProvider)
          .getAllScanRoots();
      for (final root in scanRoots) {
        await ref.read(scanRootServiceProvider).deleteScanRoot(root.id);
      }
      final items = await ref.read(whitelistServiceProvider).getAllItems();
      for (final item in items) {
        await ref.read(whitelistServiceProvider).deleteItem(item.id);
      }
      final groups = await ref.read(groupServiceProvider).getRootGroups();
      for (final group in groups) {
        await ref.read(groupServiceProvider).deleteGroupAndChildren(group.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsAllDataCleared),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.settingsClearFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
