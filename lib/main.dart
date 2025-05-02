import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ComprobanteModel.dart';
import 'ticket_model.dart';
import 'sunday_ticket_model.dart';
import 'home.dart';
import 'ReporteCaja.dart';
import 'splash.dart';
import 'pdf_optimizer.dart'; // Import our PDF optimizer

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload PDF resources on app startup to make ticket generation faster
  final pdfOptimizer = PdfOptimizer();
  try {
    // Try to preload resources during app startup
    await pdfOptimizer.preloadResources();
    print('PDF resources preloaded successfully');
  } catch (e) {
    print('Failed to preload PDF resources: $e');
    // We'll try again when needed, so continue with app startup
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TicketModel()),
        ChangeNotifierProvider(create: (_) => SundayTicketModel()),
        ChangeNotifierProvider(create: (_) => ReporteCaja()),
        ChangeNotifierProvider(create: (_) => ComprobanteModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suray',
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.amber[800],
        primarySwatch: Colors.amber,
        fontFamily: 'Roboto',
      ),
    );
  }
}