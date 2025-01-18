import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'rtc_helper.dart';

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
  final RTCHelper _rtcHelper = RTCHelper();
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

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
  }

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

        _rtcHelper.createOffer().then((offer) {
          if (offer != null) {
            final offerData = {
              'type': 'offer',
              'sdp': offer.sdp,
            };
            _channel.sink.add(jsonEncode(offerData));
          }
        });

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
