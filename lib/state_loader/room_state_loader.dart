import 'package:sputnik_persistence/sputnik_persistence.dart';
import 'package:built_collection/built_collection.dart';
import 'package:sputnik_app_state/sputnik_app_state.dart';
import 'package:sputnik_redux_store/util.dart';

class RoomStateLoader {
  static Future<RoomState> load(
    MatrixAccountDatabase database,
    String roomId,
  ) async {
    final timelineAndMembers = await loadTimelineEventStates(database, roomId);

    final reactionsAndTimeline = ReactionsMapBuilder.build(timelineAndMembers.timeline);

    return RoomState((builder) => {
          builder
            ..roomId = roomId
            ..reactions = reactionsAndTimeline.reactionsMap
            ..timelineEventStates = reactionsAndTimeline.timeline
            ..roomMembers = MapBuilder<String, UserSummary>(timelineAndMembers.members)
        });
  }

  static Future<TimelineAndMembers> loadTimelineEventStates(
    MatrixAccountDatabase database,
    String roomId,
  ) async {
    return await database.roomEventProvider.getRoomEventsWithSenderInfoFor(roomId, limit: 30);
  }
}
