import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ChatScreen extends StatefulWidget {
  final String contactId;
  const ChatScreen({super.key, required this.contactId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AppState>().ensureContactMessagesLoaded(widget.contactId);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final contact = state.contacts.firstWhere((c) => c.id == widget.contactId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ContactAvatar(initials: contact.initials, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(contact.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  Text(contact.status, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(14),
              itemCount: contact.messages.length,
              itemBuilder: (context, i) {
                final m = contact.messages.reversed.toList()[i];
                final mine = m.sender == SenderKind.user;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.indigo : AppColors.surfaceCard,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                    ),
                    child: Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary, fontSize: 14.5)),
                  ),
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            onSend: (text) {
              if (text.trim().isEmpty) return;
              context.read<AppState>().sendContactMessage(contact.id, text.trim());
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(hintText: 'Message', isDense: true),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSend(controller.text),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.indigo, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
