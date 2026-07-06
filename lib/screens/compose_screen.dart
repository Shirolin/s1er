import 'package:flutter/material.dart';

class ComposeScreen extends StatelessWidget {
  final String? tid;
  final String? fid;
  const ComposeScreen({super.key, this.tid, this.fid});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Compose')),
        body: const Center(child: Text('Compose')),
      );
}
