import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/ui/invite_code_panel.dart';
import 'package:p2p_messenger/src/ui/theme.dart';

void main() {
  const inviteCode =
      'p2p1.eyJ2IjoxLCJpZCI6InRlc3QtdXNlciIsImtleSI6ImFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6Iiwid3JpdGUiOiJ0ZXN0LXdyaXRlLWNhcGFiaWxpdHktdG9rZW4ifQ';

  for (final size in [const Size(390, 844), const Size(980, 720)]) {
    testWidgets('renders invitation QR at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var copied = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: InviteCodePanel(
                inviteCode: inviteCode,
                onCopy: () => copied = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('invite-qr')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Копировать код'));
      expect(copied, isTrue);
    });
  }
}
