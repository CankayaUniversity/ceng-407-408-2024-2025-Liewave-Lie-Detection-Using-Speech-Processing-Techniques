import 'dart:async';
import 'dart:io';
import 'dart:ui'as ui;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>  with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isRecorderInitialized = false;
  bool _isRecording = false;

  bool _isPlayerInitialized = false;
  bool _isPlaying = false;

  bool _isAnalyzing = false;

  String? _filePath;
  String? _prediction;
  String? _confidence;

  DateTime? _recordingStartTime;
  Timer? _maxDurationTimer;
  Timer? _recordingTimer;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initPlayer();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    _isPlayerInitialized = true;
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    bool granted = await _checkMicrophonePermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission not granted')),
      );
      return;
    }
    _recordingStartTime = DateTime.now();

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRecording) {
        _recordingTimer?.cancel();
      } else {
        setState(() {
          // Bu sayede UI her saniye güncellenir
        });
      }
    });

    final tempDir = Directory.systemTemp;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.aac';
    final path = '${tempDir.path}/$fileName';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );

    _recordingStartTime = DateTime.now();

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(const Duration(seconds: 60), () async {
      if (_isRecording) {
        await _stopRecording();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum recording time (60s) reached')),
        );
      }
    });

    setState(() {
      _filePath = path;
      _isRecording = true;
      _prediction = null;  // Önceki sonucu temizle
      _confidence = null;  // Önceki sonucu temizle
      _isAnalyzing = false; // Analiz modunu kapat
  });
  }

  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;
    _recordingTimer?.cancel();

    final duration = _recordingStartTime == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStartTime!);

    if (duration < const Duration(seconds: 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record at least 5 seconds')),
      );
      return;
    }

    final path = await _recorder.stopRecorder();

    _maxDurationTimer?.cancel();

    setState(() {
      _isRecording = false;
      if (path != null) {
        _filePath = path;
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _togglePlayback() async {
    if (!_isPlayerInitialized || _filePath == null) return;

    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
      });
    } else {
      try {
        await _player.startPlayer(
          fromURI: _filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            // Playback bittiğinde state güncelleniyor
            if (mounted) {
              setState(() {
                _isPlaying = false;
              });
            }
          },
        );
        setState(() {
          _isPlaying = true;
        });
      } catch (e) {
        debugPrint('Playback error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback error: $e')),
          );
        }
      }
    }
  }



  Future<String?> _uploadFileToFirebaseWithFileName(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase upload error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _sendPredictionRequest(String fileName, String userId) async {
    try {
      final uri = Uri.parse(dotenv.env['API_URL'] ?? 'https://default.url');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'path': fileName,

          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['prediction_data'];
      } else {
        debugPrint('Prediction API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error sending prediction request: $e');
      return null;
    }
  }

  Future<void> _analyzeRecording() async {
    if (_filePath == null) return;

    setState(() {
      _isAnalyzing = true;
      _prediction = null;
      _confidence = null;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final fileName = _filePath!.split(Platform.pathSeparator).last;

    try {
      final downloadUrl = await _uploadFileToFirebaseWithFileName(_filePath!, fileName);

      if (downloadUrl != null) {
        final response = await _sendPredictionRequest(fileName, userId);

        if (response != null) {
          setState(() {
            _prediction = response['prediction'] ?? 'No prediction';
            _confidence = response['confidence'] != null
                ? (response['confidence'] * 100).toStringAsFixed(1) + '%'
                : 'N/A';
            // Prediction geldiğinde animasyonu başlat
            _animController.forward();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prediction failed')),
          );
          _animController.reverse();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed')),
        );
        _animController.reverse();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      _animController.reverse();
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

   @override
  Widget build(BuildContext context) {
    final recordingDuration = _isRecording && _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;

    final bool hasPrediction = _prediction != null;

    return Scaffold(
      backgroundColor: const Color(0xFF3A7BD5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A7BD5),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'LieWave',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3A7BD5), Color(0xFF00D2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 120,
                  maxWidth: 500,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white70, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRecording)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.mic, color: Colors.redAccent, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Recording... ${recordingDuration.inSeconds}s',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    if (_isRecording) const SizedBox(height: 24),

                    // Animated mic button: Küçük ise 80x80, büyük ise 140x140
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: hasPrediction ? 80 : 140,
                        height: hasPrediction ? 80 : 140,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.redAccent : Colors.white,
                          borderRadius: BorderRadius.circular(hasPrediction ? 20 : 40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: hasPrediction ? 50 : 90,
                          icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
                          color: _isRecording ? Colors.white : Colors.black87,
                          onPressed: _toggleRecording,
                        ),
                      ),
                    ),

                    SizedBox(height: hasPrediction ? 30 : 40),

                    // Eğer prediction varsa diğer butonları ve containerı göster
                    if (!hasPrediction)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: (_filePath != null && !_isRecording) ? _togglePlayback : null,
                            icon: Icon(_isPlaying ? Icons.stop_circle : Icons.play_circle),
                            label: Text(_isPlaying ? 'Stop Playback' : 'Play Recording'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: (_filePath != null && !_isRecording && !_isAnalyzing) ? _analyzeRecording : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: const Text('Analyze Recording'),
                          ),
                        ],
                      ),

                    if (_isAnalyzing)
                      Column(
                        children: const [
                          SizedBox(height: 40),
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
                          SizedBox(height: 20),
                          Text(
                            'Analyzing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),

                    if (hasPrediction)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 40),
                          padding: const EdgeInsets.all(24),
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.45,
                            maxWidth: 500,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white70, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Prediction',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Icon(
                                _prediction!.toLowerCase() == 'truth'
                                    ? Icons.verified_outlined
                                    : (_prediction!.toLowerCase() == 'lie' ? Icons.warning_amber_rounded : Icons.help_outline),
                                size: 60,
                                color: _prediction!.toLowerCase() == 'truth'
                                    ? Colors.greenAccent
                                    : (_prediction!.toLowerCase() == 'lie' ? Colors.redAccent : Colors.blueAccent),
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child: Text(
                                  _prediction!,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: _prediction!.toLowerCase() == 'truth'
                                        ? Colors.greenAccent
                                        : (_prediction!.toLowerCase() == 'lie' ? Colors.redAccent : Colors.blueAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Confidence',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _confidence ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




