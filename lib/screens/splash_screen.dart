import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../services/api_service.dart';
import '../services/firebase_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _video;
  Timer? _watchdog;
  bool _introDone = false;
  bool _videoFailed = false;
  bool _authDone = false;
  bool _navigated = false;
  String _destination = '/login';

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset(
      'assets/videos/intro_splash.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video.addListener(_onVideo);
    _watchdog = Timer(const Duration(seconds: 20), _failVideo);
    unawaited(_startVideo());
    unawaited(_checkAuth());
    // Notification permissions must not gate playback or session validation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        FirebaseNotificationService.init().catchError((Object error) {
          debugPrint(
            'Notification initialization unavailable: ${error.runtimeType}',
          );
        }),
      );
    });
  }

  Future<void> _startVideo() async {
    try {
      await _video.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || _videoFailed) return;
      await _video.setVolume(0);
      await _video.setLooping(false);
      if (!mounted || _videoFailed) return;
      setState(() {});
      await _video.play();
      if (!mounted || _introDone) return;
      _watchdog?.cancel();
      // Handles a decoder that stalls without reporting an error.
      _watchdog = Timer(
        _video.value.duration + const Duration(seconds: 8),
        _failVideo,
      );
    } catch (_) {
      _failVideo();
    }
  }

  void _onVideo() {
    if (!mounted || _introDone) return;
    final value = _video.value;
    if (value.hasError) {
      _failVideo();
    } else if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _watchdog?.cancel();
      setState(() => _introDone = true);
      _navigateIfReady();
    }
  }

  void _failVideo() {
    if (!mounted || _introDone) return;
    _watchdog?.cancel();
    unawaited(_video.pause().catchError((Object _) {}));
    setState(() {
      _videoFailed = true;
      _introDone = true;
    });
    _navigateIfReady();
  }

  Future<void> _checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access = prefs.getString('accessToken');
      if (access != null && access.isNotEmpty) {
        // Shared HTTP client owns refresh. Temporary failure retains the session
        // and opens Home, whose existing error UI lets the user retry.
        final response = await ApiService.getCustomerProfile(
          accessToken: access,
        );
        if (prefs.getString('accessToken')?.isNotEmpty == true &&
            response.statusCode != 401) {
          _destination = '/home';
          await prefs.setBool('showEventBanner', true);
        }
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('accessToken')?.isNotEmpty == true) {
        _destination = '/home';
      }
    } finally {
      if (mounted) {
        setState(() => _authDone = true);
        _navigateIfReady();
      }
    }
  }

  void _navigateIfReady() {
    if (!mounted || !_introDone || !_authDone || _navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(context, _destination);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _video.removeListener(_onVideo);
    unawaited(_video.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFECEDE8),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFECEDE8),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: !_videoFailed && _video.value.isInitialized
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _video.value.size.width,
                              height: _video.value.size.height,
                              child: VideoPlayer(_video),
                            ),
                          ),
                        )
                      // Match the native launch screen and the video's first
                      // frame while loading or if playback is unavailable.
                      : const SizedBox.expand(),
                ),
              ),
              // Reserve space: loading never overlays any part of the video.
              SizedBox(
                height: 28,
                child: _introDone && !_authDone
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
