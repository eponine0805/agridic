import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_prefs.dart';
import '../utils/app_colors.dart';

class ConnectivitySettingsScreen extends StatefulWidget {
  final bool isFirstRun;
  const ConnectivitySettingsScreen({super.key, this.isFirstRun = false});

  @override
  State<ConnectivitySettingsScreen> createState() =>
      _ConnectivitySettingsScreenState();
}

class _ConnectivitySettingsScreenState
    extends State<ConnectivitySettingsScreen> {
  late Set<String> _selected;

  static const _options = [
    (
      id: 'text',
      icon: Icons.text_snippet_outlined,
      label: 'Text only',
      sub: 'Lightest — a few KB only\nFor weak signal or data saving',
      required: true,
    ),
    (
      id: 'manual',
      icon: Icons.auto_awesome_outlined,
      label: 'Text + Images',
      sub: 'Standard — a few hundred KB\nBest for everyday use',
      required: false,
    ),
    (
      id: 'visual',
      icon: Icons.image_outlined,
      label: 'Image-based reports',
      sub: 'Image-heavy — a few MB\nRecommended on Wi-Fi',
      required: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final prefs = context.read<ConnectivityPrefs>();
    _selected = Set.from(prefs.modes);
  }

  Future<void> _save() async {
    await context.read<ConnectivityPrefs>().saveModes(_selected);
    if (!mounted) return;
    if (widget.isFirstRun) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Download settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: !widget.isFirstRun,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isFirstRun) ...[
              const Text('Welcome to Agridict!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 8),
            ],
            const Text(
              'Choose which content to download based on your connection.\nYou can change this any time.',
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ..._options.map((opt) {
              final isOn = _selected.contains(opt.id);
              return GestureDetector(
                onTap: opt.required
                    ? null
                    : () {
                        setState(() {
                          if (isOn) {
                            _selected.remove(opt.id);
                          } else {
                            _selected.add(opt.id);
                          }
                        });
                      },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.modeActive : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOn ? AppColors.primary : AppColors.divider,
                      width: isOn ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(opt.icon,
                          color: isOn
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isOn
                                        ? AppColors.primaryDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                if (opt.required) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Required',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(opt.sub,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isOn,
                        onChanged: opt.required
                            ? null
                            : (_) {
                                setState(() {
                                  if (isOn) {
                                    _selected.remove(opt.id);
                                  } else {
                                    _selected.add(opt.id);
                                  }
                                });
                              },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.isFirstRun ? 'Save & get started' : 'Save',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
