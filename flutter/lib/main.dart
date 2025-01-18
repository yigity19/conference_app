import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _toggleVideo() async {
    if (_isStreaming) {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localRenderer.srcObject = null;
      setState(() {
        _isStreaming = false;
      });
    } else {
      final mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
        },
      };

      try {
        final stream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        _localRenderer.srcObject = stream;
        _localStream = stream;
        setState(() {
          _isStreaming = true;
        });
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 300,
              height: 200,
              child: RTCVideoView(_localRenderer),
            ),
            Positioned(
              top: 20,
              child: ElevatedButton(
                onPressed: _toggleVideo,
                child: Text(_isStreaming
                    ? 'Stop Video and Audio'
                    : 'Start Video and Audio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
