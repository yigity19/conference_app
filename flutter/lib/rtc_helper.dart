import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCHelper {
  RTCPeerConnection? _peerConnection;

  Future<void> createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('New ICE candidate: ${candidate.candidate}');
    };
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state: $state');
    };
  }

  RTCPeerConnection? get peerConnection => _peerConnection;
}
