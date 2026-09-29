import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/format.dart';
import '../models/chat_models.dart';

const kReactions = ['👍', '❤️', '😂', '🙏', '✅'];

/// Bottom sheet opened by tapping a message: react, reply, copy, save,
/// message info, and (only for the user's own messages) delete.
Future<void> showMessageActions(
  BuildContext context, {
  required ChatMessage message,
  required ValueChanged<String> onReact,
  required VoidCallback onReply,
  VoidCallback? onCopy,
  VoidCallback? onSave,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: kReactions
                  .map((e) => InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).pop();
                          onReact(e);
                        },
                        child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 24))),
                      ))
                  .toList(),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.textSecondary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(context).pop();
                onReply();
              },
            ),
            if (onCopy != null)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
                title: const Text('Copy text'),
                onTap: () {
                  Navigator.of(context).pop();
                  onCopy();
                },
              ),
            if (onSave != null)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
                title: const Text('Save to Vault'),
                subtitle: const Text('Only this item — never workflow data', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.of(context).pop();
                  onSave();
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
              title: const Text('Message info'),
              subtitle: Text(
                'Sent ${fmtTime(message.timestamp)}${message.isMine && message.status != null ? ' · ${_statusLabel(message.status!)}' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Delete message', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

String _statusLabel(String s) {
  switch (s) {
    case 'read':
      return 'Read';
    case 'delivered':
      return 'Delivered';
    default:
      return 'Sent';
  }
}

/// Bottom sheet opened from the 📎 button: a file/photo stub, or a Vault
/// result to share (result only — never the workflow behind it).
Future<void> showAttachSheet(
  BuildContext context, {
  required VoidCallback onFile,
  required VoidCallback onPhoto,
  required List<dynamic> vaultOutputs,
  required ValueChanged<dynamic> onPickOutput,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Attach', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.textSecondary),
              title: const Text('File'),
              subtitle: const Text('Campaign-Report.pdf · 2.4 MB (sample)', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.of(context).pop();
                onFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              title: const Text('Photo'),
              subtitle: const Text('IMG_2041.jpg · 1.1 MB (sample)', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.of(context).pop();
                onPhoto();
              },
            ),
            for (final o in vaultOutputs)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
                title: Text(o.title as String),
                subtitle: const Text('From Vault · shares the result only', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.of(context).pop();
                  onPickOutput(o);
                },
              ),
          ],
        ),
      ),
    ),
  );
}
