import 'dart:async';

import 'package:resqmesh/core/platform/notifications.dart';

/// Records notifications instead of showing them.
final class FakeNotifications implements AppNotifications {
  FakeNotifications({this.permitted = false});

  bool permitted;
  int permissionRequests = 0;
  final List<({String conversationId, String title, String body})> shown = [];
  final List<String> cancelled = [];

  /// The route a notification tap is waiting to deliver.
  String? openedRoute;
  final StreamController<void> _opened = StreamController.broadcast();

  /// Simulates tapping a chat's notification.
  void tap(String conversationId) => tapRoute('/chat/$conversationId');

  /// Simulates tapping a notification that opens [route].
  void tapRoute(String route) {
    openedRoute = route;
    _opened.add(null);
  }

  @override
  Stream<void> get opened => _opened.stream;

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
  Future<String?> takeOpenedRoute() async {
    final route = openedRoute;
    openedRoute = null;
    return route;
  }
}
