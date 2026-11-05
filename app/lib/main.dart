import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'pages/tabs/remote_control_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    RefenaScope(
      child: const LocalSendApp(),
    ),
  );
}

class LocalSendApp extends StatelessWidget {
  const LocalSendApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Design Tokens from Specification:
    // Teal Theme Material 3: Primary: Color(0xFF006A60), Secondary Container: Color(0xFFCCE8E3)
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006A60),
      primary: const Color(0xFF006A60),
      secondaryContainer: const Color(0xFFCCE8E3),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'LocalSend Remote Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006A60),
          brightness: Brightness.dark,
        ),
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const RemoteControlTab(),
    );
  }
}

