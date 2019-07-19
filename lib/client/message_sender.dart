import 'dart:async';
import 'dart:collection';

import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix_rest_api/matrix_client_api_r0.dart';

class SendMessageJob {
  final String transactionId;
  final Future<Response<PutEventResponse>> Function() execute;
  final _completer = Completer<Response<PutEventResponse>>();

  SendMessageJob(this.transactionId, this.execute);

  Future<Response<PutEventResponse>> get _onCompleteFuture => _completer.future;
}

class MessageSender {
  final retryCount = 3;
  final retryDelay = const Duration(seconds: 2);

  final queues = Map<String, Queue<SendMessageJob>>();
  final processLocks = Map<String, bool>();

  Future<Response<PutEventResponse>> enqueue(String roomId, SendMessageJob job) {
    createRoomQueueIfMissing(roomId);
    final queue = queues[roomId];
    queue.add(job);
    _processRoomQueue(roomId);
    return job._onCompleteFuture;
  }

  Queue<SendMessageJob> getQueue(String roomId) {
    return queues[roomId];
  }

  void createRoomQueueIfMissing(String roomId) {
    queues.putIfAbsent(roomId, () => Queue<SendMessageJob>());
    processLocks.putIfAbsent(roomId, () => false);
  }

  Future<void> _tryToProcessJob(SendMessageJob job) async {
    bool success = false;
    for (int i = 1; i <= retryCount && !success; i++) {
      try {
        final result = await job.execute();
        success = true;
        job._completer.complete(result);
      } catch (error, stack) {
        debugPrint(error.toString());
        debugPrint(stack.toString());
        debugPrint('sending message failed ${i} times ..');
        if (i == retryCount - 1) {
          debugPrint('... no more retries, completing with error');
          job._completer.completeError(error, stack);
        } else {
          debugPrint('.. retrying in ${retryDelay.inSeconds * i}s');
          await Future.delayed(retryDelay * i);
        }
      }
    }
  }

  _processRoomQueue(String roomId) async {
    if (!processLocks[roomId]) {
      try {
        processLocks[roomId] = true;
        final queue = getQueue(roomId);
        while (queue.length > 0) {
          final job = queue.removeFirst();
          await _tryToProcessJob(job);
        }
      } catch (error, trace) {
        debugPrint(error);
        debugPrint(trace.toString());
      } finally {
        processLocks[roomId] = false;
      }
    }
  }
}
