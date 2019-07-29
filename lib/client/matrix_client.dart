import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:matrix_rest_api/matrix_client_api_r0.dart';
import 'package:matrix_rest_api/matrix_identity_service_api_v1.dart';
import 'package:sputnik_matrix_sdk/util/rich_reply_util.dart';

import 'message_sender.dart';

class MatrixClient {
  final MatrixClientApi matrixApi;
  final MatrixIdentityApi identityApi;
  final Random random = Random(DateTime.now().millisecondsSinceEpoch);
  final messageSender = MessageSender();
  final Duration backOffTime = const Duration(seconds: 1);
  final String userAgent;
  final String userId;
  final String accessToken;
  final Uri homeServerBaseUrl;

  MatrixClient._(
    this.userAgent,
    this.homeServerBaseUrl,
    this.userId,
    this.accessToken,
    this.matrixApi,
    this.identityApi,
  );

  MatrixClient(
    String userAgent,
    Uri homeServerBaseUrl,
    String userId,
    String accessToken,
  ) : this._(
          userAgent,
          homeServerBaseUrl,
          userId,
          accessToken,
          MatrixClientApi(userAgent, homeServerBaseUrl, accessTokenProvider: () => accessToken),
          MatrixIdentityApi(userAgent, homeServerBaseUrl.toString()),
        );

  Future<Response<PutEventResponse>> sendTextMessage(String roomId, String message) {
    final content = GenericMessage(body: message, msgtype: 'm.text');

    String transactionId = _newTransactionId();
    debugPrint('transaction-id: $transactionId');

    return matrixApi.clientService.sendRoomEvent(
      roomId,
      'm.room.message',
      transactionId,
      content.toJson(),
    );
  }

  Future<Response<PutEventResponse>> sendReplyMessage(String roomId, RoomEvent toEvent, String reply) {
    final richReply = RichReplyUtil.richReplyFrom(ReplyToInfo(roomId, toEvent), reply);

    return matrixApi.clientService.sendRoomEvent(
      roomId,
      'm.room.message',
      _newTransactionId(),
      richReply.toJson(),
    );
  }

  Future<Response<PutEventResponse>> sendAudioMessage(String roomId, String fileName, String mediaContentUri, AudioInfo info) {
    final content = AudioMessage(
      body: fileName,
      msgtype: 'm.audio',
      url: mediaContentUri,
      info: info,
    );

    return matrixApi.clientService.sendRoomEvent(
      roomId,
      'm.room.message',
      _newTransactionId(),
      content.toJson(),
    );
  }

  Future<Response<PutEventResponse>> sendImageMessage(String roomId, String fileName, String mediaContentUri, ImageInfo info) {
    final content = ImageMessage(
      body: fileName,
      msgtype: 'm.image',
      url: mediaContentUri,
      info: info,
    );

    return matrixApi.clientService.sendRoomEvent(
      roomId,
      'm.room.message',
      _newTransactionId(),
      content.toJson(),
    );
  }

  Future<Response<ContentUriResponse>> postMediaFromFilePath(
    String fileName,
    Uri filePath,
    ContentType contentType,
  ) async {
    final file = File.fromUri(filePath);
    final length = await file.length();
    return matrixApi.mediaService.uploadStream(contentType.toString(), length.toString(), fileName, file.openRead());
  }

  Future<Response<ContentUriResponse>> postMediaFromByteList(
    String fileName,
    List<int> bytes,
    ContentType contentType,
  ) {
    return matrixApi.mediaService.upload(
      contentType.toString(),
      fileName,
      bytes,
    );
  }

  Future<Response<ContentUriResponse>> postMediaFromByteData(
    String fileName,
    ByteData byteData,
    ContentType contentType,
  ) {
    return postMediaFromByteList(fileName, byteData.buffer.asUint8List().toList(), contentType);
  }

  Future<Response<SyncResponse>> singleSync(
    String nextBatchSyncToken, {
    int longPollingTimeout = 0,
    bool enableFilter = true,
  }) {
    return matrixApi.clientService.getSync(
      nextBatchSyncToken,
      filter: enableFilter ? _syncFilter : null,
      timeout: longPollingTimeout,
    );
  }

  Future<Response<RoomMessagesResponse>> fetchRoomMessages(
    String roomId,
    String from, {
    bool backward = false,
    int limit,
    String to,
  }) {
    return matrixApi.clientService.getMessagesByRoomId(
      roomId,
      from,
      backward ? 'b' : 'f',
      limit: limit,
      to: to,
      filter: _messagesFilter,
    );
  }

  Future<Response> setReadMarker(String roomId, String eventId) {
    return matrixApi.clientService.sendReadMarkers(
      roomId,
      ReadMarkers(m_fully_read: eventId, m_read: eventId),
    );
  }

  Future<Response> redactEvent(String roomId, String eventId, String reason) {
    return matrixApi.clientService.redactEvent(roomId, eventId, _newTransactionId(), RedactRequest());
  }

  String _newTransactionId() => 'txn_${random.nextDouble()}';

  Future<Response<PutEventResponse>> sendSticker(String roomId, StickerMessageContent content) {
    return matrixApi.clientService.sendRoomEvent(roomId, 'm.sticker', _newTransactionId(), content.toJson());
  }
}

String _syncFilter = '''
  {
  "room": {
    "timeline": {
      "lazy_load_members": true
    },
    "state": {
      "lazy_load_members": true
    },
    "ephemeral": {
      "not_types": [
        "*"
      ]
    }
  },
  "presence": {
    "not_types": [
      "*"
    ]
  }
}
  '''
    .trim()
    .replaceAll(' ', '');

String _messagesFilter = '''
{
   "lazy_load_members": true
}
  '''
    .trim()
    .replaceAll(' ', '');
