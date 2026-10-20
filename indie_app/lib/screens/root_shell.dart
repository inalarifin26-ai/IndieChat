import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../state/app_state.dart';
import 'messages/messages_list_screen.dart';
import 'agents/agent_center_screen.dart';
import 'workflows/workflows_list_screen.dart';
import 'vault/vault_screen.dart';
import 'more/more_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    MessagesListScreen(),
    AgentCenterScreen(),
    WorkflowsListScreen(),
    VaultScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  selected: _index == 0,
                  badge: state.contacts.fold<int>(0, (a, c) => a + c.unread),
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Agents',
                  selected: _index == 1,
                  badge: state.agentsNeedingAttention,
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  icon: Icons.account_tree_outlined,
                  selectedIcon: Icons.account_tree_rounded,
                  label: 'Flow',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  icon: Icons.verified_user_outlined,
                  selectedIcon: Icons.verified_user_rounded,
                  label: 'Vault',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _NavItem(
                  icon: Icons.apps_rounded,
                  selectedIcon: Icons.apps_rounded,
                  label: 'More',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedIcon,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.indigo : AppColors.textFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? (selectedIcon ?? icon) : icon, color: color, size: 23),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(8)),
                      child: Text('$badge', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
