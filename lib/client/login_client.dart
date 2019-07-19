import 'dart:convert';

import 'package:matrix_rest_api/matrix_client_api_r0.dart';
import 'package:matrix_rest_api/matrix_identity_service_api_v1.dart';
import 'package:flutter/foundation.dart';

class LoginClient {
  MatrixIdentityApi _identityApi;
  MatrixClientApi _clientApi;
  final String userAgent;

  LoginClient(this.userAgent) {
    _identityApi = MatrixIdentityApi(userAgent, 'https://vector.im');
  }

  Future<Response<LoginResponse>> loginWithGenericIdAndPassword(
    String genericId,
    String password, {
    String deviceId,
    String initialDeviceDisplayName,
  }) async {
    String matrixId = await convertToMatrixId(genericId);
    return loginWithMatrixIdAndPassword(matrixId, password, deviceId: deviceId, initialDeviceDisplayName: initialDeviceDisplayName);
  }

  Future<Response<LoginResponse>> loginWithMatrixIdAndPassword(
    String matrixId,
    String password, {
    String deviceId,
    String initialDeviceDisplayName,
  }) async {
    _clientApi = await discoverAndFollowWellKnownClient(matrixId, userAgent: userAgent);
    final versions = await _clientApi.clientService.getVersions();
    debugPrint('supported versions: ${versions.body.versions.join(', ')}');
    final userIdentifier = new MatrixUserIdentifier(matrixId);

    return await _clientApi.clientService.loginWithPassword(PasswordLoginRequest(
      userIdentifier.toJson(),
      password,
      device_id: deviceId,
      initial_device_display_name: initialDeviceDisplayName,
    ));
  }

  static Future<MatrixClientApi> discoverAndFollowWellKnownClient(String matrixId, {String userAgent}) async {
    String authority = matrixId.split(':').last.trim().toLowerCase();
    Uri baseUrl;
    if (authority == null) {
      baseUrl = Uri.parse('https://matrix.org');
    } else {
      baseUrl = Uri.https(authority, '');
    }
    var clientApi = MatrixClientApi(userAgent, baseUrl);
    final result = await clientApi.discoveryService.getWellKnownClient();
    final clientInfo = result.body;
    final wellKnownBaseUrl = Uri.parse(clientInfo.m_homeserver.base_url);
    clientApi = MatrixClientApi(userAgent, wellKnownBaseUrl);
    return clientApi;
  }

  Future<String> convertToMatrixId(String input) async {
    String medium;
    String address;

    if (isEmail(input)) {
      medium = 'email';
      address = input.trim().toLowerCase();
    } else {
      String cleanText = input.replaceAll(' ', '').replaceAll('+', '').replaceFirst(RegExp(r'^00'), '');
      if (isMSISDN(cleanText)) {
        medium = 'msisdn';
        address = cleanText;
      }
    }
    String matrixId = input;
    if (medium != null) {
      final result = await _identityApi.identityService.lookup(medium, address);
      matrixId = result.body.mxid;
    }

    return matrixId;
  }

  static bool isEmail(String text) {
    final regEx = RegExp(r'^.+@.+\..+$');
    return regEx.hasMatch(text);
  }

  static bool isMSISDN(String text) {
    final regEx = RegExp(r'^(00|\+?)[1-9]{1}[0-9]{3,14}$');
    return regEx.hasMatch(text);
  }
}
