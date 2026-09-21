import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/auth/presentation/pages/profile_view.dart';
import 'package:study_sensei/features/auth/presentation/pages/pending_requests_card.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';

Future<void> showProfile(WidgetTester tester,
    {Size size = const Size(412, 915),
    double scale = 1,
    VoidCallback? onSignOut,
    VoidCallback? onEdit,
    VoidCallback? onPhoto,
    Widget? requests}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: ProfileView(
      name: 'Mayank With A Very Long Family Name',
      email: 'student.with.a.long.email@example.com',
      notificationsEnabled: true,
      onSignOut: onSignOut ?? () {},
      onEditProfile: onEdit ?? () {},
      onChangePhoto: onPhoto ?? () {},
      requests: requests ??
          PendingRequestsCard(
              loading: false,
              requests: const [],
              onAccept: (_) {},
              onDecline: (_) {}),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 180,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Profile groups expose existing account callbacks and no obsolete tools',
      (tester) async {
    var signOuts = 0;
    var edits = 0;
    var photos = 0;
    await showProfile(tester,
        onSignOut: () => signOuts++,
        onEdit: () => edits++,
        onPhoto: () => photos++);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('STUDY'), findsOneWidget);
    await tester.tap(find.byTooltip('Update profile photo'));
    expect(photos, 1);
    await reveal(tester, 'Edit profile');
    await tester.tap(find.text('Edit profile'));
    expect(edits, 1);
    await reveal(tester, 'Sign out');
    await tester.tap(find.text('Sign out'));
    expect(signOuts, 1);
    expect(find.text('APP'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    for (final term in [
      'Premium',
      'Satori',
      'App Lock Mode',
      'Focus Tools',
      'Subscription'
    ]) {
      expect(find.textContaining(term), findsNothing);
    }
  });

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets(
        'Profile long names and requests stay usable at $size with 2x text',
        (tester) async {
      await showProfile(tester, size: size, scale: 2);
      await reveal(tester, 'Friend requests');
      await tester.tap(find.text('Friend requests'));
      await tester.pumpAndSettle();
      await reveal(tester, 'No pending requests');
      expect(find.text('No pending requests'), findsOneWidget);
      await reveal(tester, 'About');
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(find.text('Show. Understand. Learn.'), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await reveal(tester, 'Sign out');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Long friend request keeps accept and decline actions usable',
      (tester) async {
    final request = FriendRequestModel(
        requestId: 'request',
        senderId: 'sender',
        senderName: 'A friend with a very long name to wrap',
        senderEmail: 'friend.with.long.email@example.com',
        sentAt: DateTime.now());
    var accepted = 0;
    var declined = 0;
    await showProfile(tester,
        size: const Size(320, 568),
        scale: 2,
        requests: PendingRequestsCard(
            loading: false,
            requests: [request],
            onAccept: (value) {
              expect(value, same(request));
              accepted++;
            },
            onDecline: (value) {
              expect(value, same(request));
              declined++;
            }));
    await reveal(tester, 'Friend requests');
    await tester.tap(find.text('Friend requests'));
    await tester.pumpAndSettle();
    await reveal(tester, 'Accept');
    await tester.tap(find.text('Accept'));
    await reveal(tester, 'Decline');
    await tester.tap(find.text('Decline'));
    expect(accepted, 1);
    expect(declined, 1);
    expect(tester.takeException(), isNull);
  });
}
