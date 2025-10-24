// user_login_page.dart
import 'dart:math' show cos, sin, asin, sqrt, pi;
import 'dart:ui' show ImageFilter;
import 'package:accident__tracker/Screens/Auth/AuthService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Redesigned user login + user home (SOS) with richer animations & polished UI.
/// All functional logic (auth, location, Firestore writes) retained from your original file.
class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _authService = AuthService();

  bool _loading = false;
  bool _isSignUp = false;
  bool _obscure = true;

  // entrance animations
  late final AnimationController _entranceController;
  late final Animation<Offset> _leftSlide;
  late final Animation<Offset> _rightSlide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _leftSlide = Tween<Offset>(begin: const Offset(-0.12, 0), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _rightSlide = Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _entranceController, curve: Curves.easeIn);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        final uid = cred.user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created successfully!')));
        Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => UserHome(uid: uid), transitionsBuilder: _pageTransition));
      } else {
        final cred = await _authService.signIn(email, password);
        final uid = cred.user!.uid;
        if (!mounted) return;
        Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => UserHome(uid: uid), transitionsBuilder: _pageTransition));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email to reset password')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  static Widget _pageTransition(BuildContext context, Animation<double> a, Animation<double> b, Widget child) {
    return FadeTransition(opacity: a, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(a), child: child));
  }

  InputDecoration _decor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: const Color(0xFF060417),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isWide ? _wideLayout() : _narrowLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: SlideTransition(position: _leftSlide, child: _leftPanel()),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: SlideTransition(position: _rightSlide, child: _authCard()),
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SlideTransition(position: _leftSlide, child: _leftPanel()),
          const SizedBox(height: 18),
          SlideTransition(position: _rightSlide, child: _authCard()),
        ],
      ),
    );
  }

  Widget _leftPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3B1E77), Color(0xFF6A3EC5)]),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // animated logo
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.local_hospital_outlined, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(_isSignUp ? 'Create account' : 'Welcome back', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              _isSignUp
                  ? 'Join to send SOS alerts easily. Your location will be shared with nearby hospitals automatically.'
                  : 'Sign in to send emergency SOS alerts to nearby hospitals and admins. Fast, accurate and private.',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                _MiniFeature(icon: Icons.location_on, label: 'Precise Location'),
                SizedBox(width: 8),
                _MiniFeature(icon: Icons.notifications_active, label: 'Instant Alerts'),
                SizedBox(width: 8),
                _MiniFeature(icon: Icons.shield, label: 'Secure'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _authCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
                children: [
                  Expanded(child: Text(_isSignUp ? 'Create account' : 'Sign in', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Switch.adaptive(key: ValueKey(_isSignUp), value: _isSignUp, onChanged: (v) => setState(() => _isSignUp = v), activeColor: Colors.deepPurpleAccent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                style: const TextStyle(color: Colors.white),
                decoration: _decor('Email', Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: _decor('Password', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => _obscure = !_obscure)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (!_isSignUp)
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?', style: TextStyle(color: Colors.white70)))),
              const SizedBox(height: 6),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _loading
                      ? const Center(key: ValueKey('loading'), child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)))
                      : ElevatedButton(
                          key: const ValueKey('btn'),
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 16)),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.05))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(color: Colors.white54))),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.05))),
              ]),
              const SizedBox(height: 12),
              _miniSosPreview(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniSosPreview() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return Card(
      color: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Hero(
            tag: 'sos-hero',
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFFFF5C5C), Color(0xFFD32F2F)])),
              child: const Icon(Icons.sos, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Emergency SOS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Notify admins within 5 km', style: TextStyle(color: Colors.white.withOpacity(0.75))),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Proceed to SOS'),
                  content: const Text('Open the SOS screen where you can send an emergency alert?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open')),
                  ],
                ),
              );
              if (proceed == true) Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => UserHome(uid: uid), transitionsBuilder: _pageTransition));
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// User Home (SOS) - Animated and polished
/// =========================
class UserHome extends StatefulWidget {
  final String uid;
  const UserHome({required this.uid, super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  bool _loading = false;
  Position? _position;
  static const double _radiusMeters = 5000.0; // 5 km

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final double toRad = pi / 180.0;
    final double dLat = (lat2 - lat1) * toRad;
    final double dLon = (lon2 - lon1) * toRad;
    final double rLat1 = lat1 * toRad;
    final double rLat2 = lat2 * toRad;
    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(rLat1) * cos(rLat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    const double R = 6371000;
    return R * c;
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location services')));
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission permanently denied. Open app settings.')));
      return false;
    }
    return true;
  }

  Future<void> _refreshPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _position = pos);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<void> _sendSos() async {
    setState(() => _loading = true);
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _position = pos);

      final userLat = pos.latitude;
      final userLng = pos.longitude;

      final snap = await FirebaseFirestore.instance.collection('hospitals').get();
      final List<Map<String, dynamic>> nearby = [];
      for (final d in snap.docs) {
        final data = d.data();
        final loc = data['location'];
        if (loc is! GeoPoint) continue;
        final dist = _distanceMeters(userLat, userLng, loc.latitude, loc.longitude);
        if (dist <= _radiusMeters) {
          nearby.add({
            'docId': d.id,
            'name': data['name'] ?? '',
            'phone': data['phone'] ?? '',
            'adminUid': data['adminUid'] ?? '',
            'location': loc,
            'distanceMeters': dist,
          });
        }
      }

      if (nearby.isEmpty) {
        if (!mounted) return;
        await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('No nearby admins found'), content: const Text('No registered hospitals/admins within 5 km.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
        return;
      }

      // show an animated bottom sheet listing recipients and confirm
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return _RecipientsSheet(nearby: nearby);
        },
      );

      if (confirmed != true) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      final userEmail = currentUser?.email ?? '';
      final userId = currentUser?.uid ?? widget.uid;

      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('sos_notifications');
      for (final h in nearby) {
        final adminUid = h['adminUid'] as String? ?? '';
        if (adminUid.isEmpty) continue;
        batch.set(col.doc(), {
          'adminUid': adminUid,
          'userUid': userId,
          'userEmail': userEmail,
          'userLocation': GeoPoint(userLat, userLng),
          'hospitalId': h['docId'],
          'hospitalName': h['name'],
          'distanceMeters': h['distanceMeters'],
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'sent',
        });
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SOS sent to ${nearby.length} nearby admin(s)')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SOS failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF060417),
      appBar: AppBar(
        title: const Text('User Home'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: _refreshPosition),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9), child: const Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(email.isEmpty ? 'Guest' : email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_position == null ? 'Location: unknown' : 'Location: ${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _loading ? null : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Emergency SOS'),
                      content: const Text('Prepare SOS alert? You will confirm recipients next.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Proceed')),
                      ],
                    ),
                  );
                  if (ok == true) await _sendSos();
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // animated pulse ring
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(alignment: Alignment.center, children: [
                      ScaleTransition(scale: _pulseAnim, child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.06)))),
                      ScaleTransition(scale: Tween(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)), child: Hero(tag: 'sos-hero', child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5C5C), Color(0xFFD32F2F)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 8))]),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.sos, size: 72, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text('EMERGENCY', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _loading ? const SizedBox(key: ValueKey('p'), height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white)) : const Text('Notify admins within 5 km', style: TextStyle(color: Colors.white70))),
                        ]),
                      ))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Tap SOS to alert nearby admins/hospitals.', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// Animated bottom sheet listing recipients and confirm action
class _RecipientsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> nearby;
  const _RecipientsSheet({required this.nearby});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.32,
      maxChildSize: 0.95,
      builder: (context, sc) {
        return Container(
          decoration: const BoxDecoration(color: Color(0xFF0B0720), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 12),
            Text('Send SOS to ${nearby.length} admin(s)?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: sc,
                itemCount: nearby.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                itemBuilder: (c, i) {
                  final h = nearby[i];
                  final km = (h['distanceMeters'] as double) / 1000.0;
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.deepPurpleAccent, child: const Icon(Icons.local_hospital_outlined, color: Colors.white)),
                    title: Text(h['name'] ?? '(no name)', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${km.toStringAsFixed(2)} km · ${h['phone'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                    trailing: IconButton(icon: const Icon(Icons.map_outlined, color: Colors.white70), onPressed: () {
                      final loc = h['location'] as GeoPoint?;
                      if (loc == null) return;
                      final url = 'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}&travelmode=driving';
                      // Use launchUrl if you have url_launcher; otherwise copy to clipboard or open externally.
                      // For brevity here, we just show a snackbar with the link.
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open map: $url')));
                    }),
                  );
                },
              ),
            ),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white12)), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Send SOS'))),
            ]),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
}
