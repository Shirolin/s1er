import 'package:flutter/material.dart';

import '../widgets/settings/settings_section.dart';
import '../widgets/s1_desktop_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return S1DesktopScaffold(
      highlightedTab: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('设置'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: const [
            SettingsSection(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
