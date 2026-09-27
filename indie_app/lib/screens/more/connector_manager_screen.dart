import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common.dart';

class ConnectorManagerScreen extends StatelessWidget {
  const ConnectorManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectors = [
      ('Google Calendar', 'Read schedule for Personal Assistant', true, Icons.calendar_today_rounded),
      ('Gmail', 'Not connected', false, Icons.mail_outline_rounded),
      ('Instagram', 'Read analytics for Marketing Agent', true, Icons.camera_alt_outlined),
      ('Cloud Storage', 'Not connected', false, Icons.cloud_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Connectors')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'External services are optional connectors, scoped and revocable — never your primary identity or storage.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          ...connectors.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(c.$4, color: c.$3 ? AppColors.cyan : AppColors.textFaint),
                  title: Text(c.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(c.$2, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                  trailing: c.$3
                      ? StatusPill(label: 'Connected', color: AppColors.success)
                      : OutlinedButton(onPressed: () {}, child: const Text('Connect')),
                ),
              )),
        ],
      ),
    );
  }
}
