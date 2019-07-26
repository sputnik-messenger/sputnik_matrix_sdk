import 'package:matrix_rest_api/matrix_client_api_r0.dart';
import 'dart:convert' show HtmlEscape, HtmlEscapeMode;

class RichReplyUtil {
  static final _startOfLine = RegExp(r'^', multiLine: true);
  static final _htmlEscape = const HtmlEscape();

  static replyBodyFor(String toUserId, String toBody, String replyText, {bool isToEmote = false}) {
    String toEmote = isToEmote ? ' * ' : '';
    String replyBody = '$toEmote<$toUserId> $toBody';
    replyBody = replyBody.replaceAll(_startOfLine, '> ');
    replyBody = '$replyBody\n\n$replyText';
    return replyBody;
  }

  static String htmlEscape(String text) {
    return _htmlEscape.convert(text);
  }

  static replyFormattedBodyFor(String toRoomId, String toEventId, String toUserId, String toHtml, String replyText, {bool isToEmote = false}) {
    String toEmote = isToEmote ? ' * ' : '';
    return '''<mx-reply>
<blockquote>
<a href="https://matrix.to/#/$toRoomId/$toEventId">In reply to</a>
$toEmote<a href="https://matrix.to/#/$toUserId">$toUserId</a>
<br />
$toHtml
</blockquote>
</mx-reply>
${_htmlEscape.convert(replyText)}
''';
  }

  static RichReply richReplyFrom(ReplyToInfo to, String reply) {
    final toIsHtml = to.toEvent.content['format'] == 'org.matrix.custom.html';
    final toBody = _toBodyFrom(to.toEvent);
    String toFormattedBody = to.toEvent.content['formatted_body'];

    if (!toIsHtml && toFormattedBody != null) {
      toFormattedBody = htmlEscape(toFormattedBody);
    }
    if (toFormattedBody == null) {
      toFormattedBody = toBody == null ? '' : htmlEscape(toBody);
    }

    String replyBody = replyBodyFor(to.toEvent.sender, toBody, reply);
    String replyHtml = replyFormattedBodyFor(to.toRoomId, to.toEvent.event_id, to.toEvent.sender, toFormattedBody, reply);

    return RichReply(
      format: 'org.matrix.custom.html',
      msgtype: 'm.text',
      m_relates_to: RelatesTo(event_id: to.toEvent.event_id),
      body: replyBody,
      formatted_body: replyHtml,
    );
  }

  static String _toBodyFrom(RoomEvent event) {
    String body = event.content['body'];
    switch (event.content['msgtype']) {
      case 'm.file':
        body = 'sent a file: $body';
        break;
      case 'm.image':
        body = 'sent an image: $body';
        break;
      case 'm.video':
        body = 'sent a video: $body';
        break;
      case 'm.image':
        body = 'sent an audio file: $body';
        break;
    }
    return body;
  }
}

class ReplyToInfo {
  final String toRoomId;
  final RoomEvent toEvent;

  ReplyToInfo(this.toRoomId, this.toEvent);
}
