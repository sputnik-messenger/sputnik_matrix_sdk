import 'package:sputnik_matrix_sdk/client/login_client.dart';
import 'package:sputnik_matrix_sdk/client/matrix_client.dart';
import 'package:sputnik_matrix_sdk/state_loader/account_state_loader.dart';
import 'package:sputnik_matrix_sdk/state_loader/app_state_loader.dart';
import 'package:chopper/chopper.dart';
import 'package:matrix_rest_api/matrix_client_api_r0.dart';
import 'package:sputnik_app_state/sputnik_app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';
import 'package:sputnik_persist_redux_mw/sputnik_persist_redux_mw.dart';
import 'package:sputnik_persistence/sputnik_persistence.dart';
import 'package:sputnik_redux_store/sputnik_redux_store.dart';

import 'account_controller.dart';

class MatrixManager {
  final String userAgent;
  final LoginClient _loginClient;
  final _clients = Map<String, MatrixClient>();
  final Map<String, MatrixAccountDatabase> _accountDatabases;
  final Store<SputnikAppState> matrixStore;
  final SputnikDatabase _matrixDatabase;

  MatrixManager._(
    this.matrixStore,
    this.userAgent,
    this._loginClient,
    this._matrixDatabase,
    this._accountDatabases,
  );

  Future<Response<LoginResponse>> addUser(
    String genericUsedId,
    String password,
    String deviceId,
    String initialDeviceDisplayName,
  ) async {
    final result = await _loginClient.loginWithGenericIdAndPassword(
      genericUsedId,
      password,
      deviceId: deviceId,
      initialDeviceDisplayName: initialDeviceDisplayName,
    );
    LoginResponse loginResponse = result.body;

    final accountSummary = AccountSummary((builder) => builder
      ..serverUrl = loginResponse.well_known?.m_homeserver?.base_url??_loginClient.serverBaseUrl.toString()
      ..userId = loginResponse.user_id
      ..displayName = loginResponse.user_id
      ..loginResponse = loginResponse);

    await _prepareAccount(accountSummary);
    matrixStore.dispatch(AddAccount(accountSummary));
    return result;
  }

  Future<void> loadAccountState(String userId) async {
    final sw = Stopwatch()..start();
    MatrixAccountDatabase db = _accountDatabases[userId];
    final accountState = await AccountStateLoader.load(db, userId);
    matrixStore.dispatch(AddAccountState(accountState));
    debugPrint('load account state for $userId in ${sw.elapsedMilliseconds}ms');
  }

  Future<void> unloadAccountState(String userId) async {
    matrixStore.dispatch(UnloadAccountState(userId));
  }

  AccountController getAccountController(String userId) {
    return AccountController(userId, matrixStore, _clients[userId], _accountDatabases[userId]);
  }

  Future<void> _prepareAccount(AccountSummary accountSummary) async {
    final sw = Stopwatch()..start();
    final db = MatrixAccountDatabase(accountSummary.userId);
    await db.open();
    _accountDatabases[accountSummary.userId] = db;
    _clients[accountSummary.userId] = MatrixClient(
      userAgent,
      Uri.parse(accountSummary.serverUrl),
      accountSummary.userId,
      accountSummary.loginResponse.access_token,
    );

    debugPrint('prepared account in ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _prepareAccounts(Iterable<AccountSummary> accountSummaries) async {
    await Future.forEach(accountSummaries, (s) => _prepareAccount(s));
  }

  Future<void> dispose() async {
    await _matrixDatabase.close();
    await Future.forEach(_accountDatabases.values, (db) => db.close());
  }

  static Future<MatrixManager> create(String userAgent) async {
    final loginClient = LoginClient(userAgent);
    final matrixDatabase = SputnikDatabase();

    final accountDatabaseMap = Map<String, MatrixAccountDatabase>();

    final middlewares = [
      AppStateMiddleware(matrixDatabase).call,
      AccountStateMiddleware(accountDatabaseMap).call,
    ];

    await matrixDatabase.open();
    final matrixState = await AppStateLoader.load(matrixDatabase);
    final store = SputnikReduxStore(matrixState, middleware: middlewares);
    final manager = MatrixManager._(
      store,
      userAgent,
      loginClient,
      matrixDatabase,
      accountDatabaseMap,
    );

    await manager._prepareAccounts(matrixState.accountSummaries.values);
    return manager;
  }
}
