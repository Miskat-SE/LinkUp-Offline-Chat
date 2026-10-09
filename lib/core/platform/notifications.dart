import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// Message notifications (spec §17, §18). Tests replace this.
abstract interface class AppNotifications {
  Future<bool> allowed();

  /// Asks Android for permission (Android 13+). Only call after explaining
  /// why (spec §17).
  Future<bool> requestPermission();

  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  });

  Future<void> cancelConversation(String conversationId);

  /// The screen a notification tap asked for (an app route), once.
  Future<String?> takeOpenedRoute();

  /// A notification was tapped; collect it with [takeOpenedRoute].
  Stream<void> get opened;
}

final class PlatformNotifications
    implements AppNotifications, NotificationFlutterApi {
  PlatformNotifications({NotificationHostApi? host})
    : _host = host ?? NotificationHostApi() {
    NotificationFlutterApi.setUp(this);
  }

  final NotificationHostApi _host;
  final StreamController<void> _opened = StreamController.broadcast();

  @override
  Stream<void> get opened => _opened.stream;

  @override
  void onNotificationOpened() => _opened.add(null);

  @override
  Future<bool> allowed() => _guard(_host.notificationsAllowed, false);

  @override
  Future<bool> requestPermission() =>
      _guard(_host.requestNotificationPermission, false);

  @override
  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  }) => _guard(
    () => _host.showMessageNotification(
      MessageNotification(
        conversationId: conversationId,
        title: title,
        body: body,
      ),
    ),
    null,
  );

  @override
  Future<void> cancelConversation(String conversationId) =>
      _guard(() => _host.cancelConversation(conversationId), null);

  @override
  Future<String?> takeOpenedRoute() => _guard(_host.takeOpenedRoute, null);

  /// Notifications are never worth crashing over.
  static Future<T> _guard<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on PlatformException {
      return fallback;
    }
  }
}

final appNotificationsProvider = Provider<AppNotifications>(
  (ref) => PlatformNotifications(),
);
