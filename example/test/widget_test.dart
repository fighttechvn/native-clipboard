import 'package:flutter_test/flutter_test.dart';
import 'package:native_clipboard_example/main.dart';

void main() {
  testWidgets('the composer starts empty and asks for a paste', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Paste an image'), findsOneWidget);
    expect(find.textContaining('paste it into the field'), findsOneWidget);
  });
}
