import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalibra/core/app_state.dart';
import 'package:kalibra/core/models.dart';
import 'package:kalibra/core/notifications.dart';
import 'package:kalibra/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pumpApp(WidgetTester tester, {bool onboarded = false}) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('id_ID');
  final app = AppState();
  await app.load();
  if (onboarded) app.completeOnboarding();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(MultiProvider(
    providers: [ChangeNotifierProvider.value(value: app), Provider.value(value: Reminders(app))],
    child: const KalibraApp(),
  ));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('pengguna baru melihat Welcome', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Ketik aja, Kalibra yang nyatet.'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
  });

  testWidgets('chat membuat draf dan Simpan semua menyimpan ke kalender', (tester) async {
    final app = await _pumpApp(tester, onboarded: true);
    await tester.enterText(find.byType(TextField).last, 'kuis alin kamis jam 10 sama deadline laprak fisdas jumat');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Simpan semua (2)'), findsOneWidget);
    expect(app.schedules, isEmpty, reason: 'tidak ada yang tersimpan tanpa konfirmasi');

    await tester.tap(find.text('Simpan semua (2)'));
    await tester.pumpAndSettle();
    expect(app.schedules.length, 2);
    expect(app.schedules.where((s) => s.kind == ScheduleKind.deadline).length, 1);
    expect(find.text('2 jadwal tersimpan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
