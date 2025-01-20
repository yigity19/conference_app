import 'dart:math';

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
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isStreaming = false;
  final RTCHelper _rtcHelper = RTCHelper();
  late WebSocketChannel _channel;
  final String _username = "user1" + Random().nextInt(100).toString();
  final String _password = "password";
  RTCSessionDescription? _offer;
  bool _didIOffer = false;

  bool _isNewOfferAwaiting = false;
  String _incomingOffer = "";

  @override
  void initState() {
    super.initState();
    initRenderers();
    _connectToSignalingServer();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _rtcHelper.dispose();
    _channel.sink.close();
    super.dispose();
  }

  /// Initializes the video renderer.
  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  /// Connects to the signaling server via WebSocket.
  void _connectToSignalingServer() {
    // Encode credentials as JSON
    final authData = jsonEncode({
      "type": "auth",
      'userName': _username,
      'password': _password,
    });

    _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8181'));

    // Send authentication data after connection is established
    _channel.sink.add(authData);

    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      switch (data['type']) {
        case 'newOfferAwaiting':
          setState(() {
            _isNewOfferAwaiting = true;
          });
          _incomingOffer = message;
          print('New offer awaiting:');
          _offer = RTCSessionDescription(data['offerSDP'], data['offerType']);
          break;
        case "answerResponse":
          print('Answer response !!!!!!!!!!!!!!!!!!!');
          _rtcHelper.peerConnection?.setRemoteDescription(
            RTCSessionDescription(data['answerSDP'], data['answerType']),
          );
          final iceCandidateData = {
            'type': 'sendIceCandidateToSignalingServer',
            "iceUserName": _username,
            "isOfferer": true,
            'icecandidate': data['candidate'],
            'sdpMid': data['sdpMid'],
            'sdpMLineIndex': data['sdpMLineIndex'],
          };
          _channel.sink.add(jsonEncode(iceCandidateData));
          break;
        case "receivedIceCandidateFromServer":
          print(
              'Response to answerer ice candidates request !!!!!!!!!!!!!!!!!!!');
          _rtcHelper.peerConnection?.addCandidate(
            RTCIceCandidate(
              data['icecandidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
          break;
        case 'candidate':
          print("======Adding ICE candidate======");
          _rtcHelper.peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
          final iceCandidateData = {
            'type': 'sendIceCandidateToSignalingServer',
            "iceUserName": _username,
            "isOfferer": _didIOffer,
            'icecandidate': data['candidate'],
            'sdpMid': data['sdpMid'],
            'sdpMLineIndex': data['sdpMLineIndex'],
          };
          _channel.sink.add(jsonEncode(iceCandidateData));
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
      _remoteRenderer.srcObject = null;
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

        await _rtcHelper.initializePeerConnection(null);

        _rtcHelper.peerConnection?.addStream(_localStream!);
        _rtcHelper.peerConnection?.onIceCandidate = (candidate) {
          final candidateData = {
            'type': 'sendIceCandidateToSignalingServer',
            "iceUserName": _username,
            "isOfferer": true,
            'icecandidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };
          _channel.sink.add(jsonEncode(candidateData));
        };

        _rtcHelper.peerConnection?.onTrack = (event) {
          if (event.track.kind == 'video') {
            _remoteRenderer.srcObject = event.streams[0];
          }
        };
        _didIOffer = true;
        final offer = await _rtcHelper.createOffer();
        if (offer != null) {
          final offerData = {
            'type': 'newOffer',
            "offererUserName": _username,
            "offerType": offer.type,
            'offerSDP': offer.sdp,
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

  Future<void> _handleNewOfferAwaiting() async {
    // Handle the new offer awaiting action here
    setState(() {
      _isNewOfferAwaiting = false;
    });

    final mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };

    try {
      // await navigator.mediaDevices.getUserMedia(mediaConstraints);
      print('Handling new offer awaiting:');
      await _rtcHelper.initializePeerConnection(_offer);
      // _rtcHelper.peerConnection?.addStream(_localStream!);
      _rtcHelper.createAnswer().then((answer) {
        final responseData = jsonDecode(_incomingOffer);

        if (answer != null) {
          final answerData = {
            'type': 'newAnswer',
            "answererUserName": _username,
            "toWhome": responseData['offererUserName'],
            "answerType": answer.type,
            'answerSDP': answer.sdp,
          };
          // _rtcHelper.peerConnection?.setLocalDescription(answer);
          final answerDataRequestIceCandidates = {
            'type': 'newAnswerReqeustIceCandidates',
            "answererUserName": _username,
            "toWhome": responseData['offererUserName'],
            "answerType": answer.type,
            'answerSDP': answer.sdp,
          };
          _channel.sink.add(jsonEncode(answerDataRequestIceCandidates));

          _channel.sink.add(jsonEncode(answerData));
        }
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                ElevatedButton(
                  onPressed: _toggleVideo,
                  child: Text(_isStreaming
                      ? 'Stop the Video Call'
                      : 'Start a Video Call'),
                ),
                if (_isNewOfferAwaiting) ...[
                  SizedBox(height: 10), // Add spacing between buttons
                  ElevatedButton(
                    onPressed: _handleNewOfferAwaiting,
                    child: Text('Handle New Offer Awaiting'),
                  ),
                ],
              ],
            ),
            SizedBox(width: 20), // Add spacing between buttons and video views
            Column(
              children: [
                Container(
                  width: 300,
                  height: 200,
                  child: RTCVideoView(_localRenderer),
                ),
                SizedBox(height: 200), // Add spacing of 200 pixels
                Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _remoteRenderer.srcObject == null
                        ? Colors.black
                        : Colors.transparent,
                  ),
                  child: RTCVideoView(_remoteRenderer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
