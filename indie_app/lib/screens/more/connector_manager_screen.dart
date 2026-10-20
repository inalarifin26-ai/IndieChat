import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api_client.dart';
import '../../models/connector_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ConnectorManagerScreen extends StatefulWidget {
  const ConnectorManagerScreen({super.key});

  @override
  State<ConnectorManagerScreen> createState() => _ConnectorManagerScreenState();
}

class _ConnectorManagerScreenState extends State<ConnectorManagerScreen> with WidgetsBindingObserver {
  bool _loading = true;
  String? _pendingProvider; // set while the browser is open for this provider

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().loadConnectors();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load connectors: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // The OAuth consent screen opens in the system browser (never inside
  // Indie — spec: the person approves on the provider's own screen). We
  // can't rely on a deep link back into the app for this MVP, so when the
  // app regains focus after a pending connect, re-check the connector list.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingProvider != null) {
      _pendingProvider = null;
      _load();
    }
  }

  Future<void> _connect(Connector c) async {
    try {
      final url = await context.read<AppState>().connectorAuthorizeUrl(c.provider);
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (opened) {
        _pendingProvider = c.provider;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approve access in your browser, then come back here.'), duration: Duration(seconds: 3)),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the browser')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 501) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This server hasn't configured this connector yet")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start connecting: ${e.message}')));
      }
    }
  }

  Future<void> _disconnect(Connector c) async {
    try {
      await context.read<AppState>().disconnectConnector(c.provider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.displayName} disconnected')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not disconnect: $e')));
    }
  }

  IconData _iconFor(String provider) {
    switch (provider) {
      case 'google_calendar':
        return Icons.calendar_today_rounded;
      case 'gmail':
        return Icons.mail_outline_rounded;
      case 'google_drive':
        return Icons.folder_outlined;
      default:
        return Icons.hub_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connectors'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'External services are optional connectors, scoped and revocable — never your primary identity or storage. Approval always happens on the provider\'s own screen.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
            else if (state.connectors.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No connectors available', style: TextStyle(color: AppColors.textFaint))))
            else
              ...state.connectors.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(_iconFor(c.provider), color: c.connected ? AppColors.accent : AppColors.textFaint),
                      title: Text(c.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(c.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                      trailing: !c.configured
                          ? const StatusPill(label: 'Unavailable', color: AppColors.textFaint)
                          : c.connected
                              ? OutlinedButton(
                                  onPressed: () => _disconnect(c),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                                  child: const Text('Disconnect'),
                                )
                              : OutlinedButton(onPressed: () => _connect(c), child: const Text('Connect')),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
