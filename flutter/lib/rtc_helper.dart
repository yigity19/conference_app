import 'package:flutter/gestures.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCHelper {
  RTCPeerConnection? _peerConnection;

  /// Creates a new RTCPeerConnection
  Future<void> initializePeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    try {
      _peerConnection = await createPeerConnection(configuration);
      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        print('New ICE candidate: ${candidate.candidate}');
      };
      _peerConnection?.onIceConnectionState = (RTCIceConnectionState? state) {
        print('ICE connection state: $state');
      };
    } catch (e) {
      print('Failed to create peer connection: $e');
    }
  }

  /// Getter for the peer connection
  RTCPeerConnection? get peerConnection => _peerConnection;
  

  /// Closes the peer connection and cleans up resources
  Future<void> dispose() async {
    try {
      await _peerConnection?.close();
      _peerConnection = null;
    } catch (e) {
      print('Failed to close peer connection: $e');
    }
  }
}
