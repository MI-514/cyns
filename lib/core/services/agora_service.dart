import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  /// Default Agora App ID.
  /// Replace this with your actual App ID from https://console.agora.io
  static const String appId = "7e464d979334457192d2bb3972935912";

  /// Optional Agora Temporary Token (If Primary Certificate is enabled in Agora Console).
  /// Leave empty string "" if using a Testing Mode project without tokens.
  static const String token = "";

  /// Check if a valid custom Agora App ID has been provided
  static bool get isAppIdConfigured {
    return appId.isNotEmpty &&
        appId != "YOUR_AGORA_APP_ID_HERE" &&
        !appId.contains("1234567890abcdef");
  }

  /// Request Microphone and Camera permissions for in-app calls
  static Future<bool> requestCallPermissions({bool isVideo = false}) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    bool micGranted =
        statuses[Permission.microphone] == PermissionStatus.granted;
    bool camGranted =
        !isVideo || statuses[Permission.camera] == PermissionStatus.granted;

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
