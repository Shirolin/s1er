import 'package:flutter/material.dart';

class ThreadDetailScreen extends StatelessWidget {
  final String tid;
  const ThreadDetailScreen({super.key, required this.tid});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Thread')),
        body: Center(child: Text('Thread $tid')),
      );
}
