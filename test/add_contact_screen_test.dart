import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/ui/add_contact_screen.dart';
import 'package:p2p_messenger/src/ui/theme.dart';

void main() {
  testWidgets('keeps manual invitation entry available without a camera', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? submittedCode;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AddContactScreen(
          cameraEnabled: false,
          addContact: (code) async {
            submittedCode = code;
            throw const FormatException('Код контакта повреждён.');
          },
        ),
      ),
    );

    expect(find.byKey(const ValueKey('code-entry')), findsOneWidget);
    expect(find.textContaining('текстовый код'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('contact-code-field')),
      'p2p1.bad-code',
    );
    await tester.tap(find.byKey(const ValueKey('add-contact-submit')));
    await tester.pumpAndSettle();

    expect(submittedCode, 'p2p1.bad-code');
    expect(find.text('Код контакта повреждён.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual entry remains usable at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AddContactScreen(
          cameraEnabled: false,
          addContact: (_) async {
            throw const FormatException('Ошибка');
          },
        ),
      ),
    );

    expect(find.byKey(const ValueKey('contact-code-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-contact-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
