import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  /// Default Agora App ID.
  /// Replace this with your actual App ID from https://console.agora.io
  static const String appId = "b1234567890abcdef1234567890abcdef";

  /// Request Microphone and Camera permissions for in-app calls
  static Future<bool> requestCallPermissions({bool isVideo = false}) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    bool micGranted = statuses[Permission.microphone] == PermissionStatus.granted;
    bool camGranted = !isVideo || statuses[Permission.camera] == PermissionStatus.granted;

    return micGranted && camGranted;
  }

  /// Initialize Agora Engine
  static Future<RtcEngine> createEngine() async {
    RtcEngine engine = createAgoraRtcEngine();
    await engine.initialize(
      const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    return engine;
  }
}
