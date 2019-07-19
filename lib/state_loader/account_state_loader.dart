import 'package:built_collection/built_collection.dart';
import 'package:sputnik_app_state/sputnik_app_state.dart';
import 'package:sputnik_persist_redux_mw/sputnik_persist_redux_mw.dart';
import 'package:sputnik_persistence/sputnik_persistence.dart';

class AccountStateLoader {
  static Future<AccountState> load(MatrixAccountDatabase db, String userId) async {
    final roomSummaries = await db.roomSummaryProvider.getAllRoomSummaries();
    final heroIds = RoomSummaryUtil.extractHeroIds(roomSummaries.map((s) => s.roomSummary));

    final heroes = await db.userSummaryProvider.getUserSummariesFor(heroIds);
    final heroesMap = Map.fromIterable(heroes, key: (h) => h.userId);

    final roomSummaryMap = MapBuilder<String, ExtendedRoomSummary>()
      ..addEntries(roomSummaries.map(
        (summary) => MapEntry(summary.roomId, summary),
      ));

    return AccountState((builder) => builder
      ..userId = userId
      ..roomStates = MapBuilder<String, RoomState>()
      ..roomSummaries = roomSummaryMap
      ..heroes = MapBuilder(heroesMap));
  }
}
