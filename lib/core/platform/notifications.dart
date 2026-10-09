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

  /// The chat a notification tap launched the app with, once.
  Future<String?> takeLaunchConversation();

  /// Chats opened by tapping a notification while the app runs.
  Stream<String> get opened;
}

final class PlatformNotifications
    implements AppNotifications, NotificationFlutterApi {
  PlatformNotifications({NotificationHostApi? host})
    : _host = host ?? NotificationHostApi() {
    NotificationFlutterApi.setUp(this);
  }

  final NotificationHostApi _host;
  final StreamController<String> _opened = StreamController.broadcast();

  @override
  Stream<String> get opened => _opened.stream;

  @override
  void onNotificationOpened(String conversationId) =>
      _opened.add(conversationId);

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
  Future<String?> takeLaunchConversation() =>
      _guard(_host.takeLaunchConversation, null);

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
