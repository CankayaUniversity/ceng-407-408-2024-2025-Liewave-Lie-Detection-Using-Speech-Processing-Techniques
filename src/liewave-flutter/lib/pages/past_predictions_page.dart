import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';

class PastPredictionsPage extends StatefulWidget {
  const PastPredictionsPage({super.key});

  @override
  State<PastPredictionsPage> createState() => _PastPredictionsPageState();
}

class _PastPredictionsPageState extends State<PastPredictionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'master',
  );
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  FlutterSoundPlayer? _player;

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _player!.openPlayer();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _player!.closePlayer();
    _player = null;
    super.dispose();
  }

  Future<void> _showPlaybackDialog(String audioPath) async {
    debugPrint('Audio path: $audioPath');
    final audioUrl = await _storage.ref(audioPath).getDownloadURL();

    showDialog(
      context: context,
      builder: (context) {
        return _AudioPlayerDialog(
          audioUrl: audioUrl,
          player: _player!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _firestore
        .collection('predictions')
        .where('user_id', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Predictions'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading predictions'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No past predictions found.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;
              final predictionData = data['predictionData'] as Map<String, dynamic>;

              final prediction = predictionData['prediction'] ?? 'Unknown';
              final confidence = (predictionData['confidence'] ?? 0.0) * 100;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final formattedTime = timestamp != null
                  ? DateFormat.yMMMd().add_jm().format(timestamp)
                  : 'Unknown date';

              
              final audioPath = doc.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    prediction.toString().toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: prediction == 'truth'
                          ? Colors.green
                          : (prediction == 'lie' ? Colors.red : Colors.grey),
                    ),
                  ),
                  subtitle: Text('Confidence: ${confidence.toStringAsFixed(1)}%\n$formattedTime'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Play audio',
                    onPressed: () {
                      _showPlaybackDialog(audioPath);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AudioPlayerDialog extends StatefulWidget {
  final String audioUrl;
  final FlutterSoundPlayer player;

  const _AudioPlayerDialog({required this.audioUrl, required this.player});

  @override
  State<_AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<_AudioPlayerDialog> {
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.player.setSubscriptionDuration(const Duration(milliseconds: 200));
    widget.player.onProgress!.listen((event) {
      if (mounted) {
        setState(() {
          _position = event.position;
          _duration = event.duration;
          if (_position >= _duration) {
            _isPlaying = false;
          }
        });
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await widget.player.pausePlayer();
      setState(() => _isPlaying = false);
    } else {
      await widget.player.startPlayer(
        fromURI: widget.audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) setState(() => _isPlaying = false);
        },
      );
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    if (_isPlaying) {
      widget.player.stopPlayer();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Play Recording',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            IconButton(
              iconSize: 72,
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
              color: Theme.of(context).primaryColor,
              onPressed: _togglePlay,
            ),
            const SizedBox(height: 12),
            Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
              onChanged: (value) async {
                final newPosition = Duration(milliseconds: value.toInt());
                await widget.player.seekToPlayer(newPosition);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(fontSize: 14)),
                Text(_formatDuration(_duration), style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_isPlaying) {
                  await widget.player.stopPlayer();
                }
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

