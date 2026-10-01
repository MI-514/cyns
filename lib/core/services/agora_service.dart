import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agora_token_service.dart';

class AgoraService {
  /// Agora App ID from Agora Console
  static const String appId = "2a01ce4bcf0549fda6d4965d7c633632";

  /// Agora Primary App Certificate from Agora Console
  static const String appCertificate = "4ef3a56e794f4dffb2105551a4752103";

  /// Generates a valid dynamic RTC token for the given channel on the fly.
  /// If an App Certificate is configured, it dynamically signs an AccessToken2 (007).
  /// If no certificate is present, it returns an empty string for Testing Mode.
  static String getTokenForChannel(String channelName, {int uid = 0}) {
    if (appCertificate.isNotEmpty) {
      final token = AgoraTokenService.generateRtcToken(
        channelName: channelName,
        uid: uid,
      );
      if (token.isNotEmpty) return token;
    }
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
