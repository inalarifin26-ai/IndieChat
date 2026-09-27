import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/indie_logo.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final contacts = [...state.contacts]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final at = a.lastMessage?.timestamp ?? DateTime(2000);
        final bt = b.lastMessage?.timestamp ?? DateTime(2000);
        return bt.compareTo(at);
      });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const IndieMark(size: 26),
            const SizedBox(width: 10),
            const Text('Messages'),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit_square)),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const Divider(indent: 78, height: 1),
        itemBuilder: (context, i) {
          final c = contacts[i];
          final last = c.lastMessage;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ContactAvatar(initials: c.initials, size: 50),
            title: Row(
              children: [
                Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (last != null) Text(timeAgo(last.timestamp), style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                last?.text ?? c.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(contactId: c.id)),
            ),
          );
        },
      ),
    );
  }
}
