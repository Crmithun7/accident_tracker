// role_selection_page.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:accident__tracker/Screens/Auth/AdminLoginPage.dart';
import 'package:accident__tracker/Screens/Auth/userloginpage.dart';
import 'package:flutter/material.dart';

/// Polished role selection page — glassmorphism + animations + responsive layout.
/// Navigates to the same pages you used previously.
class RoleSelectionPage extends StatefulWidget {
  final String? initialRole;
  const RoleSelectionPage({super.key, this.initialRole});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> with TickerProviderStateMixin {
  late final AnimationController _bgMotionController;
  late final AnimationController _staggerController;
  late final Animation<double> _bgMoveA;
  late final Animation<double> _bgMoveB;
  late final Animation<double> _bgMoveC;

  // stagger timings for header & two cards
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardAFade;
  late final Animation<Offset> _cardASlide;
  late final Animation<double> _cardBFade;
  late final Animation<Offset> _cardBSlide;

  @override
  void initState() {
    super.initState();

    // background gentle looping motion
    _bgMotionController = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _bgMoveA = Tween<double>(begin: -8.0, end: 8.0).animate(CurvedAnimation(parent: _bgMotionController, curve: Curves.easeInOut));
    _bgMoveB = Tween<double>(begin: 6.0, end: -6.0).animate(CurvedAnimation(parent: _bgMotionController, curve: Curves.easeInOut));
    _bgMoveC = Tween<double>(begin: -10.0, end: 10.0).animate(CurvedAnimation(parent: _bgMotionController, curve: Curves.easeInOut));

    // stagger entrance: using one controller and multiple intervals
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade = CurvedAnimation(parent: _staggerController, curve: const Interval(0.0, 0.28, curve: Curves.easeOut));
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _staggerController, curve: const Interval(0.0, 0.28, curve: Curves.easeOutCubic)));
    _cardAFade = CurvedAnimation(parent: _staggerController, curve: const Interval(0.28, 0.6, curve: Curves.easeOut));
    _cardASlide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(CurvedAnimation(parent: _staggerController, curve: const Interval(0.28, 0.6, curve: Curves.easeOut)));
    _cardBFade = CurvedAnimation(parent: _staggerController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut));
    _cardBSlide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(CurvedAnimation(parent: _staggerController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _bgMotionController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  static void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Which role to choose?'),
        content: const Text(
          'Choose "User" if you want to report an emergency and notify nearby admins/hospitals. '
          'Choose "Admin" if you manage a hospital and will receive SOS alerts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialRole = widget.initialRole;
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 560;

    return Scaffold(
      backgroundColor: const Color(0xFF1B002F),
      body: SafeArea(
        child: Stack(
          children: [
            // Animated decorative background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgMotionController,
                builder: (context, child) {
                  return _BackgroundDecoration(
                    offsetA: _bgMoveA.value,
                    offsetB: _bgMoveB.value,
                    offsetC: _bgMoveC.value,
                  );
                },
              ),
            ),

            // Center content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header card with slide + fade
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: _HeaderCard(initialRole: initialRole),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Role buttons with staggered animations
                      LayoutBuilder(builder: (context, constraints) {
                        final wide = constraints.maxWidth > 560;
                        if (wide) {
                          return Row(
                            children: [
                              Expanded(
                                child: SlideTransition(
                                  position: _cardASlide,
                                  child: FadeTransition(
                                    opacity: _cardAFade,
                                    child: GlassActionCard(
                                      title: 'User',
                                      subtitle: 'Report emergency & send SOS',
                                      icon: Icons.person,
                                      accent: const Color(0xFF6A1B9A),
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserLoginPage())),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: SlideTransition(
                                  position: _cardBSlide,
                                  child: FadeTransition(
                                    opacity: _cardBFade,
                                    child: GlassActionCard(
                                      title: 'Admin',
                                      subtitle: 'Manage hospital & respond to SOS',
                                      icon: Icons.admin_panel_settings_rounded,
                                      accent: Colors.redAccent,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginPage())),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              SlideTransition(
                                position: _cardASlide,
                                child: FadeTransition(
                                  opacity: _cardAFade,
                                  child: GlassActionCard(
                                    title: 'User',
                                    subtitle: 'Report emergency & send SOS',
                                    icon: Icons.person,
                                    accent: const Color(0xFF6A1B9A),
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserLoginPage())),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SlideTransition(
                                position: _cardBSlide,
                                child: FadeTransition(
                                  opacity: _cardBFade,
                                  child: GlassActionCard(
                                    title: 'Admin',
                                    subtitle: 'Manage hospital & respond to SOS',
                                    icon: Icons.admin_panel_settings_rounded,
                                    accent: Colors.redAccent,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginPage())),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      }),

                      const SizedBox(height: 22),

                      // Footer small actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => _showHelp(context),
                            child: const Text('Need help?'),
                            style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () {
                              final snack = SnackBar(content: Text('Initial role: ${initialRole ?? "not set"}'));
                              ScaffoldMessenger.of(context).showSnackBar(snack);
                            },
                            icon: const Icon(Icons.info_outline, color: Colors.white54),
                            tooltip: 'Info',
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top header card with title + subtitle + subtle logo
class _HeaderCard extends StatelessWidget {
  final String? initialRole;
  const _HeaderCard({this.initialRole});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              // small logo circle
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    child: const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
                  ),
                ),
              ),

              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role Selection',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a role to continue to the login flow.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    if (initialRole != null && initialRole!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Initial role: ${initialRole!}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large glass-like action card used for each role option.
/// Includes a gentle scale animation on tap (via InkWell + AnimatedScale) and a small chevron pulse.
class GlassActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const GlassActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<GlassActionCard> createState() => _GlassActionCardState();
}

class _GlassActionCardState extends State<GlassActionCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late final AnimationController _chevController;
  late final Animation<double> _chevAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _chevController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _chevAnim = Tween<double>(begin: 0.95, end: 1.06).animate(CurvedAnimation(parent: _chevController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _chevController.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    setState(() {
      _scale = 0.985;
      _pressed = true;
    });
  }

  void _onTapUp(_) async {
    setState(() {
      _scale = 1.0;
      _pressed = false;
    });
    await Future.delayed(const Duration(milliseconds: 90));
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _scale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // keep InkWell for ripple while GestureDetector handles scale
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_pressed ? 0.06 : 0.035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withOpacity(0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // icon bubble
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.accent.withOpacity(0.95), widget.accent.withOpacity(0.72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 6))],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  // text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(widget.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  // animated chevron
                  ScaleTransition(
                    scale: _chevAnim,
                    child: const Icon(Icons.chevron_right, color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Background decoration widget (gradient + subtle animated circles)
class _BackgroundDecoration extends StatelessWidget {
  final double offsetA;
  final double offsetB;
  final double offsetC;

  const _BackgroundDecoration({
    super.key,
    this.offsetA = 0.0,
    this.offsetB = 0.0,
    this.offsetC = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // main gradient
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF17002A), Color(0xFF3B0066)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),

      // soft shapes - use small offsets for gentle motion
      Positioned(
        left: -80 + offsetA,
        top: -80 - offsetA / 2,
        child: _SoftBlurCircle(size: 260, color: Colors.white12),
      ),
      Positioned(
        right: -40 - offsetB,
        top: 60 + offsetB / 3,
        child: _SoftBlurCircle(size: 160, color: Colors.purpleAccent.withOpacity(0.08)),
      ),
      Positioned(
        right: -120 + offsetC,
        bottom: -100 - offsetC / 2,
        child: _SoftBlurCircle(size: 340, color: Colors.redAccent.withOpacity(0.06)),
      ),

      // subtle grid overlay for depth
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
      ),
    ]);
  }
}

class _SoftBlurCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _SoftBlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 8)],
      ),
    );
  }
}

/// subtle grid painter (very light) for visual texture
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.012);
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
