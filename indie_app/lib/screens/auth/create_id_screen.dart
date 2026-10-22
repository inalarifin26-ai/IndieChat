import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/indie_logo.dart';
import 'phrase_key_screen.dart';

/// 02 · Create Your ID — choose an Indie ID (live availability) and a local PIN.
/// The account (and its recovery phrase) is created on Continue.
class CreateIdScreen extends StatefulWidget {
  const CreateIdScreen({super.key});

  @override
  State<CreateIdScreen> createState() => _CreateIdScreenState();
}

class _CreateIdScreenState extends State<CreateIdScreen> {
  final _id = TextEditingController();
  final _pin = TextEditingController();
  Timer? _debounce;
  List<String> _suggestions = [];
  String? _idError;
  bool _idOk = false;
  bool _pinBad = false;
  bool _busy = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _id.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final s = await context.read<AppState>().idSuggestions();
      if (mounted) setState(() => _suggestions = s);
    } catch (_) {
      // Suggestions are a nicety; the screen works without them.
    }
  }

  void _onIdChanged(String _) {
    _debounce?.cancel();
    setState(() {
      _idOk = false;
      _idError = null;
    });
    if (_id.text.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), _checkId);
  }

  Future<bool> _checkId() async {
    final v = _id.text.trim();
    if (v.isEmpty) return false;
    try {
      final res = await context.read<AppState>().checkIdAvailable(v);
      if (!mounted || v != _id.text.trim()) return false;
      final ok = res['valid'] == true && res['available'] == true;
      setState(() {
        _idOk = ok;
        _idError = ok ? null : (res['reason'] as String? ?? 'This ID cannot be used');
      });
      return ok;
    } catch (_) {
      // Offline check failed: let the server decide when registering.
      return true;
    }
  }

  Future<void> _continue() async {
    final pinBad = _pin.text.trim().length < 6;
    setState(() {
      _pinBad = pinBad;
      _formError = null;
    });
    if (_id.text.trim().isEmpty) {
      setState(() => _idError = 'Choose an Indie ID first');
      return;
    }
    if (!await _checkId() || pinBad) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final phrase = await context.read<AppState>().register(_pin.text.trim(), seedDemo: true, chosenId: _id.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PhraseKeyScreen(phrase: phrase)));
    } on ApiException catch (e) {
      setState(() {
        if (e.statusCode == 409 || e.statusCode == 400) {
          _idError = e.message;
          _idOk = false;
        } else {
          _formError = e.message;
        }
      });
    } catch (e) {
      setState(() => _formError = 'Could not create your ID: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          const Text('Create Your ID', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text("Your identity is your key to Indie. It's private, secure, and only yours.", style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Center(
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: 96, height: 96, decoration: const BoxDecoration(color: Color(0xFFF0F4FF), shape: BoxShape.circle), alignment: Alignment.center, child: const IndieMark(size: 54)),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 14)),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Choose your Indie ID', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _id,
            onChanged: _onIdChanged,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: 'indie_user',
              suffixText: '@indie.id',
              errorText: _idError,
              suffixIcon: _idOk ? const Icon(Icons.check_circle_rounded, color: AppColors.success) : null,
              helperText: _idOk ? 'This ID is available' : null,
              helperStyle: const TextStyle(color: AppColors.success),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Local PIN (min. 6 characters)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(controller: _pin, obscureText: true, decoration: InputDecoration(hintText: '••••••', errorText: _pinBad ? 'Use at least 6 characters' : null)),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Suggestions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            for (final s in _suggestions)
              GestureDetector(
                onTap: () {
                  _id.text = s;
                  _onIdChanged(s);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.stroke)),
                  child: Row(children: [
                    Expanded(child: Text(s, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary))),
                    const Icon(Icons.content_copy_rounded, size: 17, color: AppColors.textFaint),
                  ]),
                ),
              ),
          ],
          if (_formError != null) ...[
            const SizedBox(height: 8),
            Text(_formError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 14),
          GradientButton(label: 'Continue', loading: _busy, onPressed: _continue),
        ],
      ),
    );
  }
}
