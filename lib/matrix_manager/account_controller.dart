import 'dart:io';
import 'dart:typed_data';

import 'package:sputnik_matrix_sdk/client/matrix_client.dart';
import 'package:sputnik_matrix_sdk/matrix_manager/sync_handle.dart';
import 'package:sputnik_matrix_sdk/state_loader/room_state_loader.dart';
import 'package:sputnik_app_state/sputnik_app_state.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:sputnik_persistence/sputnik_persistence.dart';
import 'package:sputnik_redux_store/sputnik_redux_store.dart';
import 'package:redux/redux.dart';
import 'package:matrix_rest_api/matrix_client_api_r0.dart';

class AccountController {
  final String userId;
  final Store<SputnikAppState> matrixStore;
  final MatrixClient _matrixClient;
  final MatrixAccountDatabase _accountDatabase;

  final _sinceLastFetchRoomMessages = Stopwatch();

  AccountController(
    this.userId,
    this.matrixStore,
    this._matrixClient,
    this._accountDatabase,
  );

  SyncHandle startContinuousSync() {
    return SyncHandle(this);
  }

  Future<Response<SyncResponse>> sync({int longPollingTimeout, bool enableFilter = true}) async {
    final nextBatchSyncToken = _accountSummary.nextBatchSyncToken;
    final result = await _matrixClient
        .singleSync(
      nextBatchSyncToken,
      longPollingTimeout: longPollingTimeout,
      enableFilter: enableFilter,
    )
        .catchError((response, trace) {
      debugPrint(response.body.toString());
      debugPrint(trace.toString());
    }, test: (e) => e is Response);
    matrixStore.dispatch(OnSyncResponse(userId, result.body));
    return result;
  }

  AccountSummary get _accountSummary {
    return matrixStore.state.accountSummaries[userId];
  }

  Uri matrixUriToUrl(Uri mxcUri) {
    return _matrixClient.matrixApi.mediaUriConverter.matrixMediaUriToDownloadUrl(mxcUri);
  }

  Uri matrixUriToThumbnailUrl(
    Uri mxcUri, {
    int width = 512,
    int height = 512,
  }) {
    return _matrixClient.matrixApi.mediaUriConverter.matrixMediaUriToThumbnailUrl(mxcUri, width, height);
  }

  Future<void> loadRoomState(String roomId) async {
    final sw = Stopwatch()..start();
    MatrixAccountDatabase db = _accountDatabase;
    final roomState = await RoomStateLoader.load(db, roomId);
    matrixStore.dispatch(AddRoomState(userId, roomState));
    if (roomState.timelineEventStates.values.where((e) => !e.event.isStateEvent).length < 30) {
      fetchPreviousMessages(roomId);
    }
    debugPrint('load room state for $userId and $roomId in ${sw.elapsedMilliseconds}ms');
  }

  Future<void> fetchPreviousMessages(String roomId) async {
    final dbLimit = 100;
    final accountState = matrixStore.state.accountStates[userId];
    int timeLineEventsInMemory = accountState.roomStates[roomId].timelineEventStates.length;
    final timelineAndMembers =
        await _accountDatabase.roomEventProvider.getRoomEventsWithSenderInfoFor(roomId, limit: dbLimit, offset: timeLineEventsInMemory);

    if (timelineAndMembers.timeline.length > 0) {
      matrixStore.dispatch(OnLoadedTimelineTailFromDb(userId, roomId, timelineAndMembers.timeline, timelineAndMembers.members));
    }
    if (timelineAndMembers.timeline.length < dbLimit) {
      final limit = _sinceLastFetchRoomMessages.elapsed.inSeconds < 5 ? 100 : 50;
      try {
        final result =
            await _matrixClient.fetchRoomMessages(roomId, accountState.roomSummaries[roomId].previousBatchToken, backward: true, limit: limit);
        matrixStore.dispatch(OnRoomMessagesResponse(userId, roomId, result.body));
      } catch (e, trace) {
        debugPrint(e.toString());
        debugPrint(trace.toString());
      }
      _sinceLastFetchRoomMessages.reset();
      _sinceLastFetchRoomMessages.start();
    }
  }

  Future<Response<PutEventResponse>> sendTextMessage(String roomId, String message) {
    return _matrixClient.sendTextMessage(roomId, message);
  }

  Future<Response<PutEventResponse>> sendAudioMessage(String roomId, String fileName, mediaContentUri, AudioInfo info) {
    return _matrixClient.sendAudioMessage(roomId, fileName, mediaContentUri, info);
  }

  Future<Response<PutEventResponse>> sendImageMessage(String roomId, String fileName, mediaContentUri, ImageInfo info) {
    return _matrixClient.sendImageMessage(roomId, fileName, mediaContentUri, info);
  }

  Future<Response<ContentUriResponse>> postMedia(
    String fileName,
    Uri filePath,
    ContentType contentType,
  ) {
    return _matrixClient.postMedia(fileName, filePath, contentType);
  }

  Future<Response<ContentUriResponse>> postMediaByteData(
    String fileName,
    ByteData byteData,
    ContentType contentType,
  ) {
    return _matrixClient.postMediaByteData(fileName, byteData, contentType);
  }

  Future<Response> setReadMarker(String roomId, String eventId) {
    return _matrixClient.setReadMarker(roomId, eventId);
  }

  void unloadRoomState(String roomId) {
    matrixStore.dispatch(UnloadRoomState(userId, roomId));
  }
}
