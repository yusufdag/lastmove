import 'package:flutter/material.dart';

import 'theme/game_theme.dart';
import 'ui/screens/main_menu_screen.dart';

/// Root of Last Move.
class LastMoveApp extends StatelessWidget {
  const LastMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Last Move',
      debugShowCheckedModeBanner: false,
      theme: GameTheme.dark,
      home: const MainMenuScreen(),
    );
  }
}
