import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Waiting Room app launches successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<QueueProvider>(
        create: (_) => QueueProvider(),
        child: const WaitingRoomApp(),
      ),
    );

    expect(find.byType(WaitingRoomApp), findsOneWidget);
  });
}