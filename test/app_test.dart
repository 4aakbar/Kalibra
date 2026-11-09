import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalibra/core/app_state.dart';
import 'package:kalibra/core/models.dart';
import 'package:kalibra/core/notifications.dart';
import 'package:kalibra/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pumpApp(WidgetTester tester, {bool onboarded = false, bool tourDone = true}) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('id_ID');
  final app = AppState();
  await app.load();
  if (onboarded) {
    app.completeOnboarding();
    app.setTourDone(tourDone);
  }
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

  testWidgets('tur fitur 6 langkah bisa diikuti sampai selesai', (tester) async {
    final app = await _pumpApp(tester, onboarded: true, tourDone: false);
    expect(find.text('1 dari 6'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.text('${i + 1} dari 6'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
    }
    expect(find.text('6 dari 6'), findsOneWidget);
    await tester.tap(find.text('Mulai pakai'));
    await tester.pumpAndSettle();
    expect(app.tourDone, isTrue);
    expect(find.text('Lewati tur'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Lewati tur langsung menutup tur', (tester) async {
    final app = await _pumpApp(tester, onboarded: true, tourDone: false);
    await tester.tap(find.text('Lewati tur'));
    await tester.pumpAndSettle();
    expect(app.tourDone, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });
}
