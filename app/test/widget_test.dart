import 'package:flutter_test/flutter_test.dart';

import 'package:command_center/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZhiZhiApp());
    await tester.pump();
    expect(find.text('知知'), findsWidgets);
  });
}
