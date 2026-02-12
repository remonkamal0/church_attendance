import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/di/dependency_injection.dart';
import 'presentation/screens/home_screen.dart';

const supabaseUrl = 'https://xwcyduzlchmvckvuyixi.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3Y3lkdXpsY2htdmNrdnV5aXhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyODIzOTQsImV4cCI6MjA4NTg1ODM5NH0.LmUhoGj38EVqVYbjj32vHsHZnM37mAyPpDlnyr56o_k';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize dependency injection
  DependencyInjection().initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ChurchAttendanceApp());
}

class ChurchAttendanceApp extends StatelessWidget {
  const ChurchAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A3C5E),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A3C5E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DependencyInjection().createScanProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DependencyInjection().createHistoryProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'حضور كنيسة',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),

        theme: baseTheme.copyWith(
          textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
        ),

        home: const HomeScreen(),
      ),
    );
  }
}
