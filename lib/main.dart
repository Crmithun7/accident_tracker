import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:accident__tracker/Screens/Auth/roleselectionpage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep Firebase init safe across platforms
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase initialized for current platform");
    } catch (e) {
      debugPrint("⚠️ Firebase initialization failed: $e");
    }
  } else {
    debugPrint("⚠️ Skipping Firebase initialization for unsupported platform");
  }

  // Set preferred orientations and system chrome for polished look
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).catchError((_) {});

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final Color primary = Colors.deepPurple;
  static final Color accent = Colors.redAccent;

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: accent),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      ),
      textTheme: Typography.material2018().black.apply(fontFamily: 'Roboto'),
    );

    final dark = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Accident Tracker',
      theme: light,
      darkTheme: dark,
      themeMode: ThemeMode.system,
      home: const SplashWrapper(), // animated splash -> role selection
    );
  }
}

/// SplashWrapper displays a short animated splash then routes to RoleSelectionPage.
/// Keeps behavior consistent while adding modern polish.
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _showRoleSelection = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

    // Start splash animation and then reveal role selection
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _showRoleSelection = true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Animated gradient background
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.black, Colors.grey[900]!]
                : [MyApp.primary.shade400, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: _AppBrand(),
                    ),

                    const SizedBox(height: 24),

                    // Animated transition: show RoleSelectionPage inside card after splash
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: const RoleSelectionCardWrapper(),
                      crossFadeState: _showRoleSelection ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 600),
                      firstCurve: Curves.easeOut,
                      secondCurve: Curves.easeIn,
                    ),

                    const SizedBox(height: 28),

                    // Small footer / version
                    Opacity(
                      opacity: 0.85,
                      child: Text(
                        'Secure · Fast · Localized',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on Color {
  get shade400 => null;
}

/// Simple brand widget (logo text + icon). Replace with your asset/logo if you have one.
class _AppBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // circular icon
        Container(
          decoration: BoxDecoration(
            color: MyApp.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: const Icon(Icons.local_hospital, color: Colors.white, size: 36),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accident Tracker', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Emergency SOS & Hospital coordination', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// Wraps your existing RoleSelectionPage into a nice card and provides a fast route.
/// This keeps your original page intact — I only embed it inside a styled container.
class RoleSelectionCardWrapper extends StatelessWidget {
  const RoleSelectionCardWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // On large screens show side-by-side layout, on small show stacked
    final isWide = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: SizedBox(
          width: isWide ? 760 : double.infinity,
          child: isWide
              ? Row(
                  children: [
                    Expanded(child: _RoleIntro()),
                    const SizedBox(width: 18),
                    Expanded(child: _RolePanel()),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoleIntro(),
                    const SizedBox(height: 12),
                    _RolePanel(),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Left side: quick info and CTA
class _RoleIntro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose your role', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Pick whether you are a User or an Admin. Users can send SOS alerts. Admins manage hospitals and receive SOS requests.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // direct navigation to your existing RoleSelectionPage
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectionPage(initialRole: '',)));
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Open role selection'),
        ),
      ],
    );
  }
}

/// Right side: buttons for roles (styled) - keeps behavior intentionally simple,
/// and routes to your existing RoleSelectionPage (which presumably handles selection).
class _RolePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final btnStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
    );

    return Column(
      children: [
        RoleButton(
          icon: Icons.person,
          title: 'User',
          subtitle: 'Send SOS & view hospitals',
          color: Colors.deepPurple,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectionPage(initialRole: 'user')));
          },
        ),
        const SizedBox(height: 12),
        RoleButton(
          icon: Icons.admin_panel_settings,
          title: 'Admin',
          subtitle: 'Manage hospital & respond to SOS',
          color: Colors.redAccent,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectionPage(initialRole: 'admin')));
          },
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () {
            // Quick access to documentation or help - placeholder
            showAboutDialog(context: context, applicationName: 'Accident Tracker', applicationVersion: '1.0.0', children: const [
              Text('This app helps users send SOS alerts to nearby hospitals and allows admins to manage those alerts.')
            ]);
          },
          child: const Text('Learn more'),
        ),
      ],
    );
  }
}

class RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const RoleButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // card-like look for each role
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: color.withOpacity(0.06),
      splashColor: color.withOpacity(0.12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
              ]),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
