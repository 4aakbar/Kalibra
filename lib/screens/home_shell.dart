import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/occurrences.dart';
import '../ui/theme.dart';
import 'chat_screen.dart';
import 'deadline_screen.dart';
import 'kalender_screen.dart';

/// Tab yang sedang dibuka (0 Kalender, 1 Chat, 2 Deadline).
final homeTab = ValueNotifier<int>(1);

/// Teks contoh yang diisikan ke kolom Chat (dari status kosong tab lain).
final chatPrefill = ValueNotifier<String?>(null);

void openChatWith(String text) {
  chatPrefill.value = text;
  homeTab.value = 1;
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: homeTab,
      builder: (context, tab, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: tab, children: const [KalenderScreen(), ChatScreen(), DeadlineScreen()]),
        ),
        bottomNavigationBar: _TabBar(current: tab, onTap: (i) => homeTab.value = i),
      ),
    );
  }
}

/// Tab bar: Kalender (kiri), Chat (tengah, bulat, menonjol), Deadline (kanan, dengan badge).
class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final badge = context.select<AppState, int>((a) => deadlineBadgeCount(a.schedules));
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget side(int i, IconData icon, String label, {int badge = 0}) {
      final focused = current == i;
      final color = focused ? c.primary : c.inkMuted;
      return Expanded(
        child: Semantics(
          selected: focused,
          button: true,
          label: badge > 0 ? '$label, $badge perlu perhatian' : label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: SizedBox(
              height: 56,
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(icon, size: 26, color: color),
                  if (badge > 0)
                    Positioned(
                      top: -6,
                      right: -14,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.cat(CategoryId.tugas).solid,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: c.line, width: 1.5),
                        ),
                        child: Text(badge > 9 ? '9+' : '$badge',
                            style: KText.caption.copyWith(fontSize: 11, height: 1.1, color: const Color(0xFF1F1B16))),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(label,
                    style: KText.caption.copyWith(color: color, fontWeight: focused ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );
    }

    final chatFocused = current == 1;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottom > 0 ? bottom : 10),
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line, width: 1.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        side(0, Icons.calendar_month_rounded, 'Kalender'),
        Expanded(
          child: Semantics(
            selected: chatFocused,
            button: true,
            label: 'Chat, buat jadwal',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(1),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.line, width: 1.5),
                      boxShadow: [BoxShadow(color: c.shadow, offset: const Offset(3, 3))],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, size: 28, color: Colors.white),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Text('Chat',
                      style: KText.caption.copyWith(
                          color: chatFocused ? c.primary : c.inkSoft, fontWeight: chatFocused ? FontWeight.w700 : FontWeight.w500)),
                ),
              ]),
            ),
          ),
        ),
        side(2, Icons.check_box_outlined, 'Deadline', badge: badge),
      ]),
    );
  }
}
