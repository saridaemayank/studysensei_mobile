import 'package:study_sensei/features/community/presentation/pages/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_theme.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/features/groups/data/enums/group_privacy.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/models/group_chat_message.dart';
import 'package:study_sensei/features/groups/presentation/bloc/simple_group_bloc.dart';
import 'package:study_sensei/features/groups/presentation/pages/group_list_screen.dart';
import 'package:study_sensei/features/groups/presentation/widgets/group_card.dart';
import 'package:study_sensei/features/groups/presentation/widgets/group_chat_tab.dart';
import 'package:study_sensei/features/groups/presentation/widgets/add_assignment_dialog.dart';
import 'package:study_sensei/features/common/screens/startup_screen.dart';

class _Groups extends Cubit<GroupState> implements SimpleGroupBloc {
  int loads = 0;
  _Groups(super.initialState);
  @override
  void add(GroupEvent event) {
    loads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Dojos retains My Dojos and Friends subtabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const CommunityScreen(userId: ''),
    ));
    expect(find.text('My Dojos'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(TabBar));
    expect(DefaultTabController.of(context).index, 1);
    expect(tester.takeException(), isNull);
  });

  Future<void> show(WidgetTester tester, Widget screen, Size size,
      {double keyboard = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!),
        home: screen));
    await tester.pumpAndSettle();
  }

  final group = Group(
      id: 'dojo',
      name: 'A very long Dojo name for the current electricity study group',
      description: 'Share your questions and learn together.',
      createdBy: 'me',
      createdAt: DateTime(2026),
      privacy: GroupPrivacy.private,
      memberIds: ['me', 'friend']);
  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('Dojos list, empty, retry and long names fit $size at 2x',
        (tester) async {
      final bloc = _Groups(GroupLoadSuccess(groups: []));
      addTearDown(bloc.close);
      var creates = 0;
      await show(
          tester,
          BlocProvider<SimpleGroupBloc>.value(
              value: bloc,
              child: Scaffold(
                  appBar: AppBar(title: const Text('Dojos')),
                  body: GroupListScreen(
                      userId: 'me', onCreate: () => creates++))),
          size);
      expect(find.text('Studying is better together.'), findsOneWidget);
      await tester.ensureVisible(find.text('Create Dojo'));
      await tester.tap(find.text('Create Dojo'));
      expect(creates, 1);
      bloc.emit(GroupLoadSuccess(groups: [group]));
      await tester.pumpAndSettle();
      expect(find.byType(GroupCard), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'no match');
      await tester.pump();
      expect(find.textContaining('No matching Dojos'), findsOneWidget);
      bloc.emit(
          GroupFailure(errorMessage: 'FirebaseException private diagnostic'));
      await tester.pump();
      expect(find.text("Couldn't load your Dojos."), findsOneWidget);
      expect(find.textContaining('FirebaseException'), findsNothing);
      final loads = bloc.loads;
      await tester.tap(find.text('Retry'));
      expect(bloc.loads, loads + 1);
    });
    testWidgets('Dojo chat content and composer fit $size with keyboard at 2x',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var sent = 0;
      await show(
          tester,
          Scaffold(
              appBar: AppBar(title: const Text('Dojo chat')),
              body: Column(children: [
                Expanded(
                    child: ListView(children: [
                  DojoMessageBubble(
                      message: GroupChatMessage(
                          id: 'a',
                          groupId: 'd',
                          senderId: 'other',
                          senderName:
                              'A long student name that should remain readable',
                          text: List.filled(
                                  10, 'Here is my working for the problem.')
                              .join('\n'),
                          sentAt: DateTime(2026, 1, 1, 12)),
                      isCurrentUser: false),
                  DojoMessageBubble(
                      message: GroupChatMessage(
                          id: 'b',
                          groupId: 'd',
                          senderId: 'me',
                          senderName: 'Me',
                          text: 'Thank you!',
                          sentAt: DateTime(2026)),
                      isCurrentUser: true),
                ])),
                DojoChatComposer(
                    controller: controller,
                    onSend: () => sent++,
                    onCancelEditing: () {})
              ])),
          size,
          keyboard: 220);
      await tester.enterText(
          find.byType(TextField), 'Can you explain this step?');
      await tester.pump();
      expect(find.byTooltip('Send message').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Send message'));
      expect(sent, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Startup is simple dark branding with no forced animation',
      (tester) async {
    await show(tester, const StartupScreen(), const Size(320, 568));
    expect(find.text('StudySensei'), findsOneWidget);
    expect(find.text('Show. Understand. Learn.'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.background);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe-to-reply triggers only after the threshold',
      (tester) async {
    var replies = 0;
    await show(
      tester,
      Scaffold(
        body: SwipeToReplyMessage(
          onReply: () => replies++,
          child: const SizedBox(width: double.infinity, height: 72),
        ),
      ),
      const Size(320, 568),
    );

    final target = find.byType(SwipeToReplyMessage);
    await tester.drag(target, const Offset(36, 0));
    await tester.pump();
    expect(replies, 0);

    await tester.drag(target, const Offset(100, 0));
    await tester.pump();
    expect(replies, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Assignment dialog remains accessible with large text and keyboard',
      (tester) async {
    var submitted = 0;
    await show(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AddAssignmentDialog(
                            groupId: 'd',
                            currentUserId: 'me',
                            memberIds: const ['me'],
                            onAssignmentAdded: (_) => submitted++)),
                    child: const Text('Add')))),
        const Size(320, 568),
        keyboard: 180);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Revise circuits');
    await tester.ensureVisible(find.text('Add Assignment'));
    await tester.tap(find.text('Add Assignment'));
    await tester.pumpAndSettle();
    expect(submitted, 1);
    expect(tester.takeException(), isNull);
  });
}
