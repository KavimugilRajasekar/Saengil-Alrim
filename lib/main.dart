import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/birthday_provider.dart';
import 'utils/styles.dart';
import 'views/home_view.dart';

import 'services/notification_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification settings and local timezone scheduling
  await NotificationService().init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BirthdayProvider()),
      ],
      child: MaterialApp(
        title: 'saengil_alrim',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: AppStyles.bubblyFont,
          scaffoldBackgroundColor: AppColors.creamBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryPink,
            primary: AppColors.primaryPink,
            secondary: AppColors.secondaryApricot,
            surface: AppColors.cardBg,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textDark),
          ),
        ),
        home: const HomeView(),
      ),
    );
  }
}
