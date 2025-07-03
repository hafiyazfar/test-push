import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/localization/app_localizations.dart';

class LanguageSelector extends ConsumerWidget {
  final bool showTitle, isCompact;
  const LanguageSelector({super.key, this.showTitle = true, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(currentLanguageProvider);
    final supportedLanguages = ref.watch(supportedLanguagesProvider);
    final localizations = AppLocalizations.of(context);

    if (isCompact) return _buildCompactSelector(context, ref, currentLanguage, supportedLanguages, localizations);
    return _buildFullSelector(context, ref, currentLanguage, supportedLanguages, localizations);
  }

  Widget _buildCompactSelector(BuildContext context, WidgetRef ref, LanguageOption currentLanguage,
      List<LanguageOption> supportedLanguages, AppLocalizations? localizations) {
    return PopupMenuButton<LanguageOption>(
      initialValue: currentLanguage,
      onSelected: (language) => _changeLanguage(ref, language, context),
      itemBuilder: (context) => supportedLanguages.map((language) {
        return PopupMenuItem<LanguageOption>(
          value: language,
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(language.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(language.nativeName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (language == currentLanguage) Icon(Icons.check, color: Colors.green[600], size: 20),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentLanguage.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(currentLanguage.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildFullSelector(BuildContext context, WidgetRef ref, LanguageOption currentLanguage,
      List<LanguageOption> supportedLanguages, AppLocalizations? localizations) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Row(
                children: [
                  Icon(Icons.language, color: Colors.blue[600], size: 24),
                  const SizedBox(width: 12),
                  Text(localizations?.language ?? 'Language',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(localizations?.selectLanguage ?? 'Select your preferred language',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
            ],
            ...supportedLanguages.map((language) {
              final isSelected = language == currentLanguage;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _changeLanguage(ref, language, context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!, width: isSelected ? 2 : 1),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? Colors.blue[50] : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                            child: Center(child: Text(language.flag, style: const TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(language.name,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.blue[700] : Colors.black87)),
                                const SizedBox(height: 4),
                                Text(language.nativeName,
                                    style: TextStyle(
                                        fontSize: 14, color: isSelected ? Colors.blue[600] : Colors.grey[600])),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            )
                          else
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(12)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Language changes will take effect immediately throughout the app.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage(WidgetRef ref, LanguageOption language, BuildContext context) async {
    try {
      final localizationService = ref.read(localizationServiceProvider);
      await localizationService.changeLanguage(language.locale);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)?.languageChanged ?? 'Language changed successfully'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to change language: $e'), backgroundColor: Colors.red[600]));
      }
    }
  }
}

class LanguageSelectionDialog extends ConsumerWidget {
  const LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(currentLanguageProvider);
    final supportedLanguages = ref.watch(supportedLanguagesProvider);
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.language, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(localizations?.selectLanguage ?? 'Select Language'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: supportedLanguages.length,
          itemBuilder: (context, index) {
            final language = supportedLanguages[index];
            final isSelected = language == currentLanguage;
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                child: Center(child: Text(language.flag, style: const TextStyle(fontSize: 20))),
              ),
              title: Text(language.name,
                  style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue[700] : null)),
              subtitle: Text(language.nativeName, style: TextStyle(color: isSelected ? Colors.blue[600] : Colors.grey[600])),
              trailing: isSelected ? Icon(Icons.check_circle, color: Colors.blue[600]) : null,
              onTap: () async {
                try {
                  final localizationService = ref.read(localizationServiceProvider);
                  await localizationService.changeLanguage(language.locale);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(AppLocalizations.of(context)?.languageChanged ?? 'Language changed successfully'),
                        backgroundColor: Colors.green[600]));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Failed to change language: $e'), backgroundColor: Colors.red[600]));
                  }
                }
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations?.cancel ?? 'Cancel'))],
    );
  }
}

class LanguageDropdown extends ConsumerWidget {
  final bool showLabel;
  final EdgeInsets? padding;
  const LanguageDropdown({super.key, this.showLabel = true, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(currentLanguageProvider);
    final supportedLanguages = ref.watch(supportedLanguagesProvider);
    final localizations = AppLocalizations.of(context);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(localizations?.language ?? 'Language', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<LanguageOption>(
            value: currentLanguage,
            decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: supportedLanguages.map((language) {
              return DropdownMenuItem<LanguageOption>(
                value: language,
                child: Row(
                  children: [
                    Text(language.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(language.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(language.nativeName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (language) async {
              if (language != null) {
                try {
                  final localizationService = ref.read(localizationServiceProvider);
                  await localizationService.changeLanguage(language.locale);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(AppLocalizations.of(context)?.languageChanged ?? 'Language changed successfully'),
                        backgroundColor: Colors.green[600]));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Failed to change language: $e'), backgroundColor: Colors.red[600]));
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
} 