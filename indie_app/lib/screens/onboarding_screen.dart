import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../state/app_state.dart';
import '../widgets/indie_logo.dart';
import 'root_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

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
            const SizedBox(height: 24),
            const IndieMark(size: 44),
            const SizedBox(height: 10),
            const Text('Indie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const Text('Independent Intelligence', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
            const SizedBox(height: 18),
            TabBar(
              controller: _tabs,
              indicatorColor: AppColors.cyan,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textFaint,
              tabs: const [Tab(text: 'Create ID'), Tab(text: 'Log in'), Tab(text: 'Recover')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [_RegisterTab(), _LoginTab(), _RecoverTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint);

class _RegisterTab extends StatefulWidget {
  const _RegisterTab();
  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _credential = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_credential.text.trim().length < 6) {
      setState(() => _error = 'Use at least 6 characters for your local credential.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final phrase = await context.read<AppState>().register(_credential.text.trim(), seedDemo: true);
      if (!mounted) return;
      await _showRecoveryPhraseDialog(context, phrase);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootShell()), (r) => false);
    } catch (e) {
      setState(() => _error = e.toString());
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
          'This creates a new Personal ID — no email or phone number needed. '
          'Set a local credential to unlock the app on this device.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        ),
        const SizedBox(height: 18),
        TextField(controller: _credential, obscureText: true, decoration: _dec('Local credential', hint: 'At least 6 characters')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const _BtnSpinner() : const Text('Create my Personal ID'),
        ),
        const SizedBox(height: 10),
        const Text(
          "You'll be shown a 12-word recovery phrase once — save it somewhere safe. "
          'It is the only way to recover your account if you lose this device.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11.5),
        ),
      ],
    );
  }
}

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

Future<void> _showRecoveryPhraseDialog(BuildContext context, String phrase) {
  bool saved = false;
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Save your recovery phrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is shown only once. Anyone with these 12 words can recover your account — store them somewhere private and offline.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.stroke)),
              child: SelectableText(phrase, style: const TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Checkbox(
                  value: saved,
                  activeColor: AppColors.indigo,
                  onChanged: (v) => setState(() => saved = v ?? false),
                ),
                const Expanded(child: Text("I've saved this phrase somewhere safe", style: TextStyle(fontSize: 12.5))),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: saved ? () => Navigator.of(ctx).pop() : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}
