import 'package:built_collection/built_collection.dart';
import 'package:sputnik_persistence/sputnik_persistence.dart';
import 'package:sputnik_app_state/sputnik_app_state.dart';


class AppStateLoader {
  static Future<SputnikAppState> load(SputnikDatabase database) async {
    final accountSummaries = await database.accountSummaryProvider.getAllAccountSummaries();

    final accountSummaryMap = MapBuilder<String, AccountSummary>()
      ..addEntries(accountSummaries.map(
        (s) => MapEntry(s.userId, s),
      ));

    final state = SputnikAppState((builder) => builder
      ..accountSummaries = accountSummaryMap
      ..accountStates = MapBuilder<String, AccountState>());

    return state;
  }
}
