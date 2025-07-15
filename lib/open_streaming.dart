import 'package:flutter/material.dart';

class OpenStreaming extends StatelessWidget {
  const OpenStreaming({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenStreaming'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Center(
        child: Text(
          'OpenStreaming',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
