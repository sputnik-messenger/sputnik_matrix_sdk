import 'package:matrix_rest_api/src/api/matrix_client_api/r0/model/model.dart';

class MessageContentMapper {
  static dynamic typedContentFrom(Map<String, dynamic> content) {
    String type = content['msgtype'];
    switch (type) {
      case 'm.text':
        return TextMessage.fromJson(content);
      case 'm.image':
        return ImageMessage.fromJson(content);
      case 'm.video':
        return VideoMessage.fromJson(content);
      case 'm.notice':
        return NoticeMessage.fromJson(content);
      case 'm.audio':
        return AudioMessage.fromJson(content);
      case 'm.emote':
        return EmoteMessage.fromJson(content);
      case 'm.file':
        return FileMessage.fromJson(content);
      default:
        return GenericMessage.fromJson(content);
    }
  }
}
