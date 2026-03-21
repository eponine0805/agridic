import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../utils/app_colors.dart';
import 'post_card.dart';

/// アバター編集ボトムシートを表示し、選択・圧縮・保存まで一括処理する
Future<void> showAvatarEditor(BuildContext context) async {
  final userPrefs = context.read<UserPrefs>();
  final choice = await showModalBottomSheet<_AvatarChoice>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AvatarChoiceSheet(
      avatarBase64: userPrefs.avatarBase64,
    ),
  );

  if (choice == null || !context.mounted) return;

  if (choice == _AvatarChoice.remove) {
    await context.read<UserPrefs>().updateAvatar('');
    return;
  }

  final source =
      choice == _AvatarChoice.gallery ? ImageSource.gallery : ImageSource.camera;
  final picker = ImagePicker();
  final file = await picker.pickImage(source: source, imageQuality: 90);
  if (file == null || !context.mounted) return;

  final rawBytes = await file.readAsBytes();
  final compressed = await FlutterImageCompress.compressWithList(
    rawBytes,
    minWidth: 120,
    minHeight: 120,
    quality: 80,
  );
  final base64Str = 'data:image/jpeg;base64,${base64Encode(compressed)}';
  if (context.mounted) {
    await context.read<UserPrefs>().updateAvatar(base64Str);
  }
}

enum _AvatarChoice { gallery, camera, remove }

class _AvatarChoiceSheet extends StatelessWidget {
  final String avatarBase64;
  const _AvatarChoiceSheet({required this.avatarBase64});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarBase64.isNotEmpty;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // プレビュー
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                hasAvatar
                    ? AvatarImage(base64: avatarBase64, radius: 44)
                    : CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: const Icon(Icons.person,
                            size: 44, color: AppColors.primary),
                      ),
                const SizedBox(height: 8),
                const Text(
                  'Edit avatar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: AppColors.primary),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, _AvatarChoice.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined,
                color: AppColors.primary),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, _AvatarChoice.camera),
          ),
          if (hasAvatar)
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Remove avatar',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(context, _AvatarChoice.remove),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
