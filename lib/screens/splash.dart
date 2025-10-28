import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home.dart';
import '../utils/pdf_resource_manager.dart';
import '../utils/pdf_optimizer.dart';
import '../utils/generateTicket.dart';
import '../utils/generate_mo_ticket.dart';
import '../utils/generateCargo_Ticket.dart';
import '../models/ComprobanteModel.dart';
import '../utils/ReporteCaja.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  bool _resourcesLoaded = false;
  double _loadingProgress = 0.0;
  String _loadingStatus = "Iniciando...";

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    // Start preloading resources
    _preloadResources();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _preloadResources() async {
    try {
      // Set minimum time for splash screen (2 seconds)
      final minSplashDelay = Future.delayed(Duration(seconds: 2));

      // Update loading status
      _updateLoadingStatus("Cargando recursos...", 0.1);

      // Initialize resource manager
      final resourceManager = PdfResourceManager();
      await resourceManager.initialize();
      _updateLoadingStatus("Optimizando PDF...", 0.3);

      // Initialize PDF optimizer
      final pdfOptimizer = PdfOptimizer();
      await pdfOptimizer.preloadResources();
      _updateLoadingStatus("Preparando generadores...", 0.5);

      // Initialize ticket generators in parallel
      await Future.wait([
        _preloadGenerateTicket(),
        _preloadMoTicket(),
        _preloadCargoTicket(context),
      ]);

      _updateLoadingStatus("Finalizando...", 0.9);

      // Make sure minimum splash time has passed
      await minSplashDelay;

      // Mark resources as loaded
      setState(() {
        _resourcesLoaded = true;
        _loadingProgress = 1.0;
        _loadingStatus = "¡Listo!";
      });

      // Navigate to home screen after a short delay
      Future.delayed(Duration(milliseconds: 300), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Home()),
        );
      });
    } catch (e) {
      print('Splash: Error during preloading: $e');

      // Even on error, continue to home after a delay
      _updateLoadingStatus("Continuando...", 1.0);

      await Future.delayed(Duration(seconds: 1));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Home()),
      );
    }
  }

  Future<void> _preloadGenerateTicket() async {
    try {
      final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
      final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
      final generateTicket = GenerateTicket(comprobanteModel, reporteCaja);
      await generateTicket.preloadResources();
      return;
    } catch (e) {
      print('Error preloading GenerateTicket: $e');
    }
  }

  Future<void> _preloadMoTicket() async {
    try {
      final moTicketGenerator = MoTicketGenerator();
      await moTicketGenerator.preloadResources();
      return;
    } catch (e) {
      print('Error preloading MoTicketGenerator: $e');
    }
  }

  Future<void> _preloadCargoTicket(BuildContext context) async {
    try {
      final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
      final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

      final cargoGen = CargoTicketGenerator(comprobanteModel, reporteCaja);
      await cargoGen.preloadResources();
      return;
    } catch (e) {
      print('Error preloading CargoTicketGenerator: $e');
    }
  }

  void _updateLoadingStatus(String status, double progress) {
    if (mounted) {
      setState(() {
        _loadingStatus = status;
        _loadingProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber[800],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            FadeTransition(
              opacity: _animation,
              child: ScaleTransition(
                scale: _animation,
                child: Image.asset(
                  'assets/logo.png',
                  width: 200,
                  height: 200,
                ),
              ),
            ),

            SizedBox(height: 40),

            // Loading indicators
            Container(
              width: 240,
              child: Column(
                children: [
                  // Progress bar
                  LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.amber[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),

                  SizedBox(height: 10),

                  // Loading text
                  Text(
                    _loadingStatus,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}