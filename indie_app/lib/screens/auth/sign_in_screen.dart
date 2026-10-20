import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/indie_logo.dart';
import '../root_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const IndieFullLogo(width: 150),
            const SizedBox(height: 14),
            TabBar(
              controller: _tabs,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textFaint,
              tabs: const [Tab(text: 'Log in'), Tab(text: 'Recover')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [_LoginTab(), _RecoverTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint);

class _LoginTab extends StatefulWidget {
  const _LoginTab();
  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _personalId = TextEditingController();
  final _credential = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(_personalId.text.trim(), _credential.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootShell()), (r) => false);
    } catch (e) {
      setState(() => _error = 'Could not log in — check your Personal ID and credential.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _personalId, decoration: _dec('Personal ID', hint: 'e.g. craft.ugly77')),
        const SizedBox(height: 12),
        TextField(controller: _credential, obscureText: true, decoration: _dec('Local credential')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const _BtnSpinner() : const Text('Log in')),
      ],
    );
  }
}

class _RecoverTab extends StatefulWidget {
  const _RecoverTab();
  @override
  State<_RecoverTab> createState() => _RecoverTabState();
}

class _RecoverTabState extends State<_RecoverTab> {
  final _personalId = TextEditingController();
  final _phrase = TextEditingController();
  final _newCredential = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_newCredential.text.trim().length < 6) {
      setState(() => _error = 'New credential must be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().recover(_personalId.text.trim(), _phrase.text.trim(), _newCredential.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootShell()), (r) => false);
    } catch (e) {
      setState(() => _error = 'Could not recover — check your Personal ID and recovery phrase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Lost access to this device? Prove ownership with your 12-word recovery '
          'phrase and set a new local credential. This revokes every other active session.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        TextField(controller: _personalId, decoration: _dec('Personal ID')),
        const SizedBox(height: 12),
        TextField(controller: _phrase, maxLines: 2, decoration: _dec('Recovery phrase', hint: '12 words separated by spaces')),
        const SizedBox(height: 12),
        TextField(controller: _newCredential, obscureText: true, decoration: _dec('New local credential')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const _BtnSpinner() : const Text('Recover account')),
      ],
    );
  }
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}
