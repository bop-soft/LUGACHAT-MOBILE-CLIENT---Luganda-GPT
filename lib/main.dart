import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

enum TtsState { playing, stopped, paused, continued }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Transcription',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TranscriptionPage(),
    );
  }
}

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
    late FlutterTts flutterTts;
  final  _record = AudioRecorder();
  bool _isRecording = false;
  String _transcription = 'Your transcription will appear here.';

  /// Start recording audio.
  Future<void> _startRecording() async {
    final Directory tempDir = await getTemporaryDirectory();
    final String path = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';  
    if (await _record.hasPermission()) {
      await _record.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _transcription = 'Recording...';
      });
    } else {
      setState(() {
        _transcription = 'Microphone permission denied.';
      });
    }
  }

  /// Stop recording and send the audio file to the Flask API.
  Future<void> _stopRecording() async {
    // Stop the recording and get the temporary file path.
    final String? filePath = await _record.stop();
    setState(() {
      _isRecording = false;
    });

    if (filePath != null) {
      await _sendAudioFile(File(filePath));
    } else {
      setState(() {
        _transcription = 'Recording failed or was cancelled.';
      });
    }
  }

  /// Send the recorded audio file to the Flask endpoint.
  Future<void> _sendAudioFile(File audioFile) async {
    setState(() {
      _transcription = 'Uploading audio for transcription...';
    });
    
    try {
      // Replace with your Flask endpoint URL.
      // For Android emulator, use http://10.0.2.2:5000/transcribe if your server runs locally.
      // var uri = Uri.parse('http://10.0.2.2:5000/transcribe');
      var uri = Uri.parse('http://192.168.100.150:5000/transcribe');
      var request = http.MultipartRequest('POST', uri);

      // Attach the audio file under the key "audio".
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      // Send the request.
      var response = await request.send();

      // Parse the response.
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        setState(() {
          _transcription = data['transcription'] ?? 'No transcription found.';
        });
      } else {
        setState(() {
          _transcription = 'Error: Received status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _transcription = 'Error: $e';
      });
    }
  }

  /// Toggle recording on button press.
  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  @override
  void initState() {
    flutterTts = FlutterTts();
    super.initState();
  }

    Future<void> _speak(String text) async {
    await flutterTts.setVolume(0.5);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);

    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Transcription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  _transcription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            if (_transcription.isNotEmpty)
             Padding(
               padding: const EdgeInsets.all(8.0),
               child: ElevatedButton.icon(
                onPressed:()=>_speak(_transcription),
                icon: Icon(Icons.speaker),
                label: Text('Start Speaking'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                           ),
             ),
            ElevatedButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
