/// Tur fitur pertama kali: layar digelapkan, satu area dibiarkan terang
/// (spotlight), lalu tooltip muncul di dekatnya. Jalan di atas app yang asli.
library;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// Titik-titik yang disorot tur.
class TourKeys {
  static final chatTab = GlobalKey(debugLabel: 'tour-chat-tab');
  static final composer = GlobalKey(debugLabel: 'tour-composer');
  static final kalenderTab = GlobalKey(debugLabel: 'tour-kalender-tab');
  static final viewSwitch = GlobalKey(debugLabel: 'tour-view-switch');
  static final deadlineTab = GlobalKey(debugLabel: 'tour-deadline-tab');
  static final avatar = GlobalKey(debugLabel: 'tour-avatar');
}

class TourStep {
  /// Tab yang dibuka saat langkah ini (0 Kalender, 1 Chat, 2 Deadline).
  final int tab;
  final GlobalKey target;
  final String text;
  final bool circle;
  const TourStep(this.tab, this.target, this.text, {this.circle = false});
}

final tourSteps = [
  TourStep(1, TourKeys.chatTab, 'Ini pusatnya. Ketik jadwal kayak ngechat temen.', circle: true),
  TourStep(
    1,
    TourKeys.composer,
    'Tulis aja, misal "Rapat BEM Jumat jam 4 sore". Kalibra bikin draf, kamu cek dulu, baru simpan.',
  ),
  TourStep(1, TourKeys.kalenderTab, 'Jadwal yang disimpan langsung masuk Kalender, lengkap dengan pengingat.'),
  TourStep(0, TourKeys.viewSwitch, 'Ganti tampilan Bulan, Minggu, atau Hari sesukamu. Titik warna = kategori.'),
  TourStep(2, TourKeys.deadlineTab, 'Semua tugas urut dari yang paling mepet. Geser ke kanan buat tandai selesai.'),
  TourStep(1, TourKeys.avatar, 'Atur pengingat, tema, dan akun di sini.', circle: true),
];

class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.onTab, required this.onDone});

  /// Pindah tab supaya target langkah terlihat.
  final ValueChanged<int> onTab;
  final VoidCallback onDone;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with SingleTickerProviderStateMixin {
  int step = 0;
  Rect? rect;

  /// Ukuran area overlay (dipakai untuk menaruh tooltip di atas/bawah target).
  Size area = Size.zero;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    _show(0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _show(int i) {
    final s = tourSteps[i];
    widget.onTab(s.tab);
    // Tunggu tab tergambar dulu (dua frame), baru ukur posisi target.
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      binding.addPostFrameCallback((_) => _measure(i));
      binding.ensureVisualUpdate();
    });
    binding.ensureVisualUpdate();
  }

  void _measure(int i) {
    if (!mounted) return;
    final s = tourSteps[i];
    final box = s.target.currentContext?.findRenderObject() as RenderBox?;
    final overlay = context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) {
      // Target tidak ada (misal layar terlalu kecil): lewati langkah ini.
      step = i;
      _next();
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    setState(() {
      step = i;
      rect = topLeft & box.size;
      area = overlay.size;
    });
    if (!_reduceMotion) _pulse.repeat(count: 2);
  }

  void _next() {
    if (step + 1 >= tourSteps.length) {
      widget.onDone();
    } else {
      _show(step + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.k;
    final s = tourSteps[step];
    final r = rect;
    final duration = _reduceMotion ? Duration.zero : const Duration(milliseconds: 380);
    final hole = r == null
        ? null
        : s.circle
        ? Rect.fromCircle(center: r.center, radius: r.longestSide / 2 + 8)
        : r.inflate(6);
    final below = hole != null && hole.center.dy < area.height / 2;
    final last = step == tourSteps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: hole == null
                  ? const ColoredBox(color: Color(0x99000000))
                  : TweenAnimationBuilder<Rect?>(
                      tween: RectTween(end: hole),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: _SpotlightPainter(
                            hole: value,
                            circle: s.circle,
                            pulse: _pulse.isAnimating ? _pulse.value : 0,
                            ring: c.accent,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (hole != null)
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeOutCubic,
              left: 20,
              right: 20,
              top: below ? hole.bottom + 16 : null,
              bottom: below ? null : area.height - hole.top + 16,
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${step + 1} dari ${tourSteps.length}', style: KText.caption.copyWith(color: c.inkMuted)),
                    const SizedBox(height: 4),
                    Text(s.text, style: KText.subtitle.copyWith(color: c.ink)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,

                        children: [
                          TextButton(
                            onPressed: widget.onDone,
                            child: Text('Lewati tur', style: KText.label.copyWith(color: c.inkMuted)),
                          ),
                          KButton(
                            label: last ? 'Mulai pakai' : 'Lanjut',
                            small: true,
                            expand: false,
                            icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                            onPressed: _next,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.circle, required this.pulse, required this.ring});
  final Rect? hole;
  final bool circle;
  final double pulse;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0x99000000);
    final h = hole;
    if (h == null) {
      canvas.drawRect(Offset.zero & size, dim);
      return;
    }
    final radius = Radius.circular(circle ? h.shortestSide / 2 : 16);
    // Even-odd: area di luar lubang digelapkan, lubangnya tetap terang.
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(h, radius));
    canvas.drawPath(mask, dim);
    // Cincin berdenyut di sekeliling area yang disorot.
    final grow = 10 * pulse;
    final ringRect = h.inflate(grow);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ring.withValues(alpha: 1 - pulse);
    canvas.drawRRect(RRect.fromRectAndRadius(ringRect, Radius.circular(radius.x + grow)), paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole || old.pulse != pulse || old.circle != circle;
}
