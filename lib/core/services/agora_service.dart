import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  /// Agora App ID from Agora Console
  static const String appId = "2a01ce4bcf0549fda6d4965d7c633632";

  /// SECURE ARCHITECTURE: App Certificate is removed from client-side source code.
  /// Token generation is handled securely via trusted backend / Cloud Functions.
  static const String appCertificate = "";

  /// Generates or fetches a valid dynamic RTC token for the given channel.
  static String getTokenForChannel(String channelName, {int uid = 0}) {
    // In production, fetch token securely from trusted backend / Firebase Cloud Functions.
    return '';
  }

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
