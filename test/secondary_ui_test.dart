import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/features/friends/data/models/user_model.dart';
import 'package:study_sensei/features/friends/presentation/pages/friend_detail_screen.dart';
import 'package:study_sensei/features/friends/presentation/widgets/user_list_tile.dart';

void main() {
  final friend = UserModel(
    id: 'friend-id',
    name: 'A very long student name that should remain readable',
    email: 'a.long.student.email@example.school',
    phone: '+91 1234567890',
    createdAt: DateTime(2025, 1, 1),
  );
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('Friend detail stays readable at $size and large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: FriendDetailScreen(friend: friend),
      ));
      await tester.pump();
      expect(find.text(friend.name), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Added On'), 180);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Friend action remains accessible with long identity',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
          body: UserListTile(user: friend, onAddFriend: () => requests++)),
    ));
    await tester.tap(find.byTooltip('Add Friend'));
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });
}
