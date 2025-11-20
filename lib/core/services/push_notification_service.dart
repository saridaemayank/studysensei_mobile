import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/core/navigation/navigation_service.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/assignment/assignment_bloc.dart';
import 'package:study_sensei/features/groups/presentation/pages/group_details_screen.dart';

/// Handles Firebase Cloud Messaging setup, token registration, and navigation
/// when the user interacts with chat notifications.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tracks the group (dojo) that is currently open in the UI so that
  /// duplicate navigation isn't triggered.
  final ValueNotifier<String?> activeGroupId = ValueNotifier<String?>(null);

  bool _initialized = false;
  bool _permissionGranted = false;
  String? _currentUserId;
  RemoteMessage? _pendingNavigationMessage;

  /// Provide your Firebase web push certificate key if web push is used.
  /// It can also be injected at build time using `--dart-define=WEB_PUSH_KEY=<key>`.
  final String _webPushKey =
      const String.fromEnvironment('WEB_PUSH_KEY', defaultValue: '');

  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _permissionGranted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (_permissionGranted) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _messaging.onTokenRefresh.listen((token) {
      _registerToken(token: token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingNavigationMessage = initialMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final message = _pendingNavigationMessage;
        _pendingNavigationMessage = null;
        if (message != null) {
          _handleMessageNavigation(message);
        }
      });
    }

    await _registerToken();

    _initialized = true;
  }

  /// Notifies the service that a user has signed in so the current token can be stored.
  Future<void> onUserSignedIn(String uid) async {
    _currentUserId = uid;
    await _registerToken();
  }

  /// Clears local state when the user signs out.
  void onUserSignedOut() {
    _currentUserId = null;
    activeGroupId.value = null;
  }

  /// Keeps track of which dojo chat is currently visible.
  void trackActiveGroup(String? groupId) {
    activeGroupId.value = groupId;
  }

  Future<void> _registerToken({String? token}) async {
    if (!_permissionGranted) return;

    final uid = _currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint(
        'PushNotificationService: No authenticated user for token registration.',
      );
      return;
    }

    final resolvedToken = token ??
        await _messaging.getToken(
          vapidKey: _webPushKey.isNotEmpty ? _webPushKey : null,
        );

    if (resolvedToken == null || resolvedToken.isEmpty) {
      debugPrint('PushNotificationService: Unable to obtain FCM token.');
      return;
    }

    await _firestore.collection('users').doc(uid).set({
      'fcmToken': resolvedToken,
      'fcmTokens': [resolvedToken],
      'tokens': [resolvedToken],
      'lastFcmTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final previewLength =
        resolvedToken.length >= 12 ? 12 : resolvedToken.length;
    debugPrint(
      'PushNotificationService: Registered token for $uid (${resolvedToken.substring(0, previewLength)}...).',
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final groupId = message.data['groupId'] as String?;

    if (groupId != null && groupId == activeGroupId.value) {
      debugPrint(
        'PushNotificationService: Ignoring foreground notification for active group $groupId.',
      );
      return;
    }

    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final groupName =
        message.data['groupName'] ?? message.data['group'] ?? 'your dojo';
    final senderName =
        message.data['senderName'] ?? message.notification?.title ?? 'Sensei';
    final messagePreview = message.data['messageText'] ??
        message.data['message'] ??
        message.data['body'] ??
        message.notification?.body ??
        '';
    final title = 'You have a new message from $groupName';
    final subtitle = messagePreview.isNotEmpty
        ? '$senderName: $messagePreview'
        : 'Sent by $senderName';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        action: groupId != null
            ? SnackBarAction(
                label: 'Open',
                onPressed: () => _handleMessageNavigation(message),
              )
            : null,
      ),
    );
  }

  Future<void> _handleMessageNavigation(RemoteMessage message) async {
    final groupId = message.data['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) {
      debugPrint(
        'PushNotificationService: Received notification without a groupId.',
      );
      return;
    }

    if (groupId == activeGroupId.value) {
      debugPrint(
        'PushNotificationService: Chat for group $groupId already open, skipping navigation.',
      );
      return;
    }

    final navigator = NavigationService.navigatorKey.currentState;
    final context = NavigationService.navigatorKey.currentContext;

    if (navigator == null || context == null) {
      _pendingNavigationMessage = message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingNavigationMessage;
        _pendingNavigationMessage = null;
        if (pending != null) {
          _handleMessageNavigation(pending);
        }
      });
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'PushNotificationService: User not authenticated, cannot open group chat.',
      );
      return;
    }

    try {
      final groupDoc =
          await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists || groupDoc.data() == null) {
        debugPrint(
          'PushNotificationService: Group $groupId does not exist, cannot open.',
        );
        return;
      }

      final group = Group.fromMap(groupDoc.id, groupDoc.data()!);

      final assignmentBloc = AssignmentBloc()..add(LoadAssignments(group.id));

      navigator
          .push(
        MaterialPageRoute(
          builder: (ctx) => BlocProvider.value(
            value: assignmentBloc,
            child: GroupDetailsScreen(
              group: group,
              currentUserId: user.uid,
            ),
          ),
        ),
      )
          .then((_) {
        assignmentBloc.close();
      });
    } catch (e) {
      debugPrint(
        'PushNotificationService: Failed to navigate to group $groupId. $e',
      );
    }
  }
}

