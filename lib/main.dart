import 'package:flutter/material.dart';
import 'package:muse_mate/drop_music.dart';
import 'package:muse_mate/open_streaming.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _openStreaming() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OpenStreaming()),
    );
  }

  void _openDropMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DropMusic()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text('메뉴', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('스트리밍 열기'),
              onTap: () {
                Navigator.pop(context);
                _openStreaming();
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_drop_down),
              title: const Text('드랍'),
              onTap: () {
                Navigator.pop(context);
                _openDropMenu();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(),
    );
  }
}