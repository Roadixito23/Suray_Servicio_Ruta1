import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ComprobanteModel.dart';
import 'ticket_model.dart';
import 'sunday_ticket_model.dart';
import 'home.dart';
import 'ReporteCaja.dart'; // Asegúrate de importar el archivo
import 'splash.dart'; // Importar el splash screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: SplashScreen(), // Iniciar con el splash screen en lugar de Home
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.amber[800],
        primarySwatch: Colors.amber,
        fontFamily: 'Roboto',
      ),
    );
  }
}