import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:greate_note_app/core/widgets/splash_background.dart';
import 'package:greate_note_app/features/folders/presentation/screens/folder_page.dart';
import '../../../notes/data/data_sources/note_local_datasource.dart';
import 'bloc/splash_bloc.dart';

class SplashScreen extends StatefulWidget {
  final NoteLocalDataSource noteLocalDataSource;

  const SplashScreen({super.key, required this.noteLocalDataSource});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    BlocProvider.of<SplashBloc>(context).add(StartSplash());

    // Initialize animation controllers
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _scaleController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);

    // Define slide animation
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.5), end: const Offset(0, 0.1))
            .animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    // Define fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Define scale animation
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Start animations sequentially
    _slideController.forward();
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return BlocListener<SplashBloc, SplashState>(
      listener: (context, state) {
        if (state is SplashCompleted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => FolderPage(
                noteLocalDataSource: widget.noteLocalDataSource,
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const SplashBackground(),

            // Animated logo and app name
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        SizedBox(
                          height: screenHeight * 0.25,
                          child: Image.asset(
                            'assets/images/quill.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App name with gradient
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.8),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Great Note',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tagline
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            'Capture Your Thoughts',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
