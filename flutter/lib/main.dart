import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'rtc_helper.dart';

/// The main entry point of the Flutter application.

void main() {
  runApp(const MyApp());
}

/// The root widget of the application.
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

/// The home page of the application.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// Renderer for displaying the local video stream.
  final _localRenderer = RTCVideoRenderer();

  /// The local media stream.
  MediaStream? _localStream;

  /// Flag indicating whether streaming is active.
  bool _isStreaming = false;

  /// Helper class for managing WebRTC connections.
  final RTCHelper _rtcHelper = RTCHelper();

  /// WebSocket channel for signaling.
  late WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    initRenderers();
    _connectToSignalingServer();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    _rtcHelper.dispose();
    _channel.sink.close();
    super.dispose();
  }

  /// Initializes the video renderer.
  Future<void> initRenderers() async {
    await _localRenderer.initialize();
  }

  /// Connects to the signaling server via WebSocket.
  void _connectToSignalingServer() {
    _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8181'));

    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      switch (data['type']) {
        case 'offer':
          _rtcHelper.peerConnection?.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['type']),
          );
          _rtcHelper.createAnswer();
          break;
        case 'answer':
          _rtcHelper.peerConnection?.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['type']),
          );
          break;
        case 'candidate':
          _rtcHelper.peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
          break;
      }
    });
  }

  /// Toggles the video stream on and off.
  Future<void> _MakeCall() async {
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

        await _rtcHelper.initializePeerConnection();
        _rtcHelper.peerConnection?.onIceCandidate = (candidate) {
          final candidateData = {
            'type': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };
          _channel.sink.add(jsonEncode(candidateData));
        };

        final offer = await _rtcHelper.createOffer();
        if (offer != null) {
          final offerData = {
            'type': 'newOffer',
            'sdp': offer.sdp,
          };
          _channel.sink.add(jsonEncode(offerData));
        }

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
            SizedBox(
              width: 600,
              height: 400,
              child: RTCVideoView(_localRenderer),
            ),
            Positioned(
              top: 100,
              child: ElevatedButton(
                onPressed: _MakeCall,
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
