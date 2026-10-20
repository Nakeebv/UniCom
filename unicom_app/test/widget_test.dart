import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unicom/shared/widgets/logo.dart';

void main() {
  testWidgets('UniCom logo mark renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: UniComLogo(size: 64))),
    );
    expect(find.byType(UniComLogo), findsOneWidget);
  });
}
