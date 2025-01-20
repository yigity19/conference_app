import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCHelper {
  RTCPeerConnection? _peerConnection;
  RTCSessionDescription? _offer = null;
  RTCSessionDescription? get offer => _offer;

  /// Creates a new RTCPeerConnection and sets the given offer as the local description
  Future<void> initializePeerConnection(RTCSessionDescription? offer) async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    try {
      _peerConnection = await createPeerConnection(configuration);
      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {};
      _peerConnection?.onIceConnectionState = (RTCIceConnectionState? state) {
        print('ICE connection state: $state');
      };

      // Set the given offer as the local description

      if (offer != null) {
        RTCSignalingState? signalingState = _peerConnection?.signalingState;
        if (signalingState != null) {
          print(
              'Signaling state: $signalingState'); // Replace this with the logging framework
        }
        await _peerConnection?.setRemoteDescription(offer);
        signalingState = _peerConnection?.signalingState;
        if (signalingState != null) {
          print(
              'Signaling state: $signalingState'); // Replace this with the logging framework
        }

        print('Set local description with offer:');
      } else {
        print('Offer is null');
      }
    } catch (e) {
      print('Failed to create peer connection: $e');
    }
  }

  /// Creates an SDP offer and sets it as the local description
  Future<RTCSessionDescription?> createOffer() async {
    if (_peerConnection == null) {
      print('Peer connection is not initialized');
      return null;
    }

    try {
      _offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(_offer!);
      print('Created offer:');
      return _offer;
    } catch (e) {
      print('Failed to create offer: $e');
      return null;
    }
  }

  Future<RTCSessionDescription?> createAnswer() async {
    if (_peerConnection == null) {
      print('Peer connection is not initialized');
      return null;
    }

    try {
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      print('Created answer !!!!!!!!!!!!!!!!!!!!');
      return answer;
    } catch (e) {
      print('Failed to create answer: $e');
      return null;
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
