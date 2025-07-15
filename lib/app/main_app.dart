import 'package:flutter/material.dart';
import 'package:muse_mate/screen/drop_music_screen.dart';
import 'package:muse_mate/screen/open_streaming_screen.dart';
import 'package:muse_mate/app/chat_app.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': Icons.play_arrow,
      'title': '스트리밍 열기',
      'screen': const OpenStreaming(),
    },
    {'icon': Icons.arrow_drop_down, 'title': '드랍', 'screen': const DropMusic()},
    {'icon': Icons.chat, 'title': '채팅', 'screen': const ChatApp()},
  ];

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
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
              child: Text(
                '메뉴',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ..._menuItems.map(
              (item) => ListTile(
                leading: Icon(item['icon']),
                title: Text(item['title']),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScreen(item['screen']);
                },
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(),
    );
  }
}
