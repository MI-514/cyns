import 'package:agora_token_generator/agora_token_generator.dart';

class AgoraTokenService {
  static const String appId = "2a01ce4bcf0549fda6d4965d7c633632";
  static const String appCertificate = "4ef3a56e794f4dffb2105551a4752103";

  /// Generates a dynamic RTC token for any channel and user on the fly.
  static String generateRtcToken({
    required String channelName,
    int uid = 0,
    int expireSeconds = 86400, // 24 hours
  }) {
    try {
      final token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: channelName,
        uid: uid,
        tokenExpireSeconds: expireSeconds,
      );
      return token;
    } catch (_) {
      return '';
    }
  }
}
