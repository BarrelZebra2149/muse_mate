import 'package:flutter/material.dart';

class DropMusic extends StatelessWidget {
  const DropMusic({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DropMusic'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Center(
        child: Text(
          'DropMusic',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
