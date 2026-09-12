import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/identity/anonymous_identity.dart';
import 'package:p2p_messenger/src/ui/onboarding_screen.dart';
import 'package:p2p_messenger/src/ui/theme.dart';

void main() {
  const identity = AnonymousIdentity(
    userId: 'test-user-id',
    displayName: 'Аноним test',
    publicKey: <int>[1, 2, 3],
    privateSeed: <int>[4, 5, 6],
    fingerprint: 'abcd efgh',
    inboxReadToken: 'read-token',
    inboxWriteToken: 'write-token',
  );

  testWidgets('requires recovery-code confirmation before entering the app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ready = false;

    await tester.pumpWidget(
      _TestApp(identity: identity, onReady: () async => ready = true),
    );
    await tester.tap(find.byKey(const ValueKey('create-identity')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('recovery-code')), findsOneWidget);
    var finish = tester.widget<FilledButton>(
      find.byKey(const ValueKey('finish-onboarding')),
    );
    expect(finish.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('confirm-backup')));
    await tester.pump();
    finish = tester.widget<FilledButton>(
      find.byKey(const ValueKey('finish-onboarding')),
    );
    expect(finish.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('finish-onboarding')));
    await tester.pumpAndSettle();

    expect(ready, isTrue);
  });

  testWidgets('shows a validation error for a bad restore code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _TestApp(identity: identity));
    await tester.tap(find.text('Восстановить по коду'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('restore-code')),
      'сломанный код',
    );
    await tester.tap(find.byKey(const ValueKey('restore-identity')));
    await tester.pumpAndSettle();

    expect(find.text('Код повреждён'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.identity, this.onReady});

  final AnonymousIdentity identity;
  final Future<void> Function()? onReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: OnboardingScreen(
        onCreateIdentity: () async => identity,
        onRestoreIdentity: (_) async {
          throw const FormatException('Код повреждён');
        },
        onReady: onReady ?? () async {},
      ),
    );
  }
}
