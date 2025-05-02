import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'pdf_resource_manager.dart';
import 'pdf_optimizer.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';
import 'ticket_model.dart';
import 'sunday_ticket_model.dart';
import 'splash.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Start resource preloading in background
  unawaited(_preloadPdfResources());

  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ComprobanteModel()),
        ChangeNotifierProvider(create: (context) => ReporteCaja()),
        ChangeNotifierProvider(create: (context) => TicketModel()),
        ChangeNotifierProvider(create: (context) => SundayTicketModel()),
      ],
      child: MyApp(),
    ),
  );
}

// Preload PDF resources in background
Future<void> _preloadPdfResources() async {
  try {
    print('Main: Starting background PDF resource initialization');

    // Initialize the resource manager
    final resourceManager = PdfResourceManager();
    await resourceManager.initialize();

    // Initialize the PDF optimizer
    final pdfOptimizer = PdfOptimizer();
    await pdfOptimizer.preloadResources();

    print('Main: Background PDF resource initialization complete');
  } catch (e) {
    print('Main: Error preloading PDF resources: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Helper for fire-and-forget Futures
void unawaited(Future<void> future) {
  // Explicitly ignore the result of the future
  future.then((_) {
    // Do nothing on completion
  }).catchError((error) {
    // Log errors, don't crash
    print('Unawaited Future error: $error');
  });
}