import 'package:flutter/material.dart';

class ForumListScreen extends StatelessWidget {
  final String fid;
  const ForumListScreen({super.key, required this.fid});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forum')),
        body: Center(child: Text('Forum $fid')),
      );
}
