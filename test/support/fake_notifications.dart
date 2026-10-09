import 'dart:async';

import 'package:resqmesh/core/platform/notifications.dart';

/// Records notifications instead of showing them.
final class FakeNotifications implements AppNotifications {
  FakeNotifications({this.permitted = false});

  bool permitted;
  int permissionRequests = 0;
  final List<({String conversationId, String title, String body})> shown = [];
  final List<String> cancelled = [];
  String? launchConversation;
  final StreamController<String> _opened = StreamController.broadcast();

  /// Simulates tapping a notification.
  void tap(String conversationId) => _opened.add(conversationId);

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<bool> allowed() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permitted = true;
  }

  @override
  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  }) async =>
      shown.add((conversationId: conversationId, title: title, body: body));

  @override
  Future<void> cancelConversation(String conversationId) async =>
      cancelled.add(conversationId);

  @override
  Future<String?> takeLaunchConversation() async {
    final id = launchConversation;
    launchConversation = null;
    return id;
  }
}
