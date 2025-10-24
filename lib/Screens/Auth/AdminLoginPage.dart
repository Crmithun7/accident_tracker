// admin_login_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:accident__tracker/Screens/Auth/AuthService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Polished Admin flow with improved UI & animations:
/// - animated background gradient
/// - staggered form fields
/// - refined glass buttons
/// - responsive layout (row -> column)
/// - animated SOS tiles with delay
/// - animated unread SOS badge in AppBar
/// - correct marker pulse (scale + opacity use AnimatedBuilder)
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> with TickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _adminSecret = TextEditingController();
  final AuthService _authService = AuthService();

  bool _loading = false;
  bool _isSignUp = false;
  static const String _adminSecretValue = '2468';

  late final AnimationController _bgController;
  late final Animation<Color?> _bgA;
  late final Animation<Color?> _bgB;

  late final AnimationController _formAnim;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _formFade;

  // staggered controllers for fields inside the right card
  late final List<AnimationController> _fieldControllers;
  late final List<Animation<Offset>> _fieldSlides;
  late final List<Animation<double>> _fieldFades;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _bgA = ColorTween(begin: const Color(0xFF09021F), end: const Color(0xFF2E0261)).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
    _bgB = ColorTween(begin: const Color(0xFF2C0546), end: const Color(0xFF6A00F4)).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    _formAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _formAnim, curve: Curves.easeOutCubic));
    _formFade = CurvedAnimation(parent: _formAnim, curve: Curves.easeIn);
    _formAnim.forward();

    _fieldControllers = List.generate(4, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 520)));
    _fieldSlides = _fieldControllers
        .map((c) => Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)))
        .toList();
    _fieldFades = _fieldControllers.map((c) => CurvedAnimation(parent: c, curve: Curves.easeIn)).toList();

    // Staggered start
    for (var i = 0; i < _fieldControllers.length; i++) {
      Timer(Duration(milliseconds: 110 * i), () {
        if (mounted) _fieldControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _adminSecret.dispose();
    _bgController.dispose();
    _formAnim.dispose();
    for (final c in _fieldControllers) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _inputDec({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final secret = _adminSecret.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email & password')));
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        if (secret != _adminSecretValue) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid admin secret')));
          return;
        }

        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        final uid = cred.user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin account created')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminRegisterHospitalPage(adminUid: uid)));
      } else {
        final cred = await _authService.signIn(email, password);
        final uid = cred.user!.uid;
        final isAdmin = await _authService.isAdmin(uid, forceRefresh: true);
        if (!isAdmin) {
          await _authService.signOut();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access denied: Not an admin')));
          return;
        }
        final hasHospital = await _adminHasHospital(uid);
        if (!mounted) return;
        if (hasHospital) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard(adminUid: uid)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminRegisterHospitalPage(adminUid: uid)));
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _adminHasHospital(String uid) async {
    try {
      final q = await FirebaseFirestore.instance.collection('hospitals').where('adminUid', isEqualTo: uid).limit(1).get();
      return q.docs.isNotEmpty;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not check hospitals: $e')));
      return false;
    }
  }

  Widget _fieldAnimated({required Widget child, required int idx}) {
    return SlideTransition(
      position: _fieldSlides[idx],
      child: FadeTransition(opacity: _fieldFades[idx], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 880;

    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgA.value ?? const Color(0xFF09021F), _bgB.value ?? const Color(0xFF2C0546)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20, vertical: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 1200 : 720),
                    child: SlideTransition(
                      position: _formSlide,
                      child: FadeTransition(
                        opacity: _formFade,
                        child: isWide ? Row(children: [Expanded(flex: 4, child: _leftCard()), const SizedBox(width: 36), Expanded(flex: 5, child: _rightCard())]) : Column(children: [_leftCard(), const SizedBox(height: 24), _rightCard()]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leftCard() {
    return _LeftInfoCard(isSignUp: _isSignUp);
  }

  Widget _rightCard() {
    return Card(
      elevation: 28,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)]),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(_isSignUp ? 'Admin — Create Account' : 'Admin — Login', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isSignUp ? _devBadge() : const SizedBox(key: ValueKey('empty'), width: 8),
            )
          ]),
          const SizedBox(height: 26),
          _fieldAnimated(child: TextField(controller: _email, decoration: _inputDec(label: 'Email')), idx: 0),
          const SizedBox(height: 14),
          _fieldAnimated(child: TextField(controller: _password, decoration: _inputDec(label: 'Password'), obscureText: true), idx: 1),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isSignUp ? (_fieldAnimated(child: TextField(controller: _adminSecret, decoration: _inputDec(label: 'Admin secret (dev)'), obscureText: true), idx: 2)) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 22),
          _fieldAnimated(
            idx: 3,
            child: GlassButton(
              label: _loading ? 'Working…' : (_isSignUp ? 'Create Admin' : 'Login'),
              icon: _isSignUp ? Icons.person_add : Icons.login,
              onTap: _loading ? null : _submit,
              busy: _loading,
            ),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_isSignUp ? 'Already registered?' : 'Need an admin account?', style: TextStyle(color: Colors.white.withOpacity(0.9))),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                  _formAnim
                    ..reset()
                    ..forward();
                  // reset staggered fields
                  for (var i = 0; i < _fieldControllers.length; i++) {
                    _fieldControllers[i].reset();
                    Timer(Duration(milliseconds: 100 * i), () {
                      if (mounted) _fieldControllers[i].forward();
                    });
                  }
                });
              },
              child: Text(_isSignUp ? 'Login' : 'Sign up', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ])
        ]),
      ),
    );
  }

  Widget _devBadge() {
    return Container(
      key: const ValueKey('dev'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.18), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.orangeAccent.withOpacity(0.25))),
      child: const Text('DEV', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
    );
  }
}

/// Left info card (polished)
class _LeftInfoCard extends StatefulWidget {
  final bool isSignUp;
  const _LeftInfoCard({required this.isSignUp});

  @override
  State<_LeftInfoCard> createState() => _LeftInfoCardState();
}

class _LeftInfoCardState extends State<_LeftInfoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slide = Tween<Offset>(begin: const Offset(-0.06, 0), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedScale(
            scale: _hover ? 1.01 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: Card(
              elevation: 18,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)]),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                      child: const Icon(Icons.admin_panel_settings, size: 34, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.isSignUp ? 'Create Admin' : 'Welcome back', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  ]),
                  const SizedBox(height: 18),
                  Text('Manage hospitals, receive SOS alerts in real-time and trace users on the map. Quick responses save lives.', style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.5)),
                  const SizedBox(height: 20),
                  Row(children: const [
                    Expanded(child: _MiniFeature(icon: Icons.location_on, label: 'Trace users')),
                    SizedBox(width: 12),
                    Expanded(child: _MiniFeature(icon: Icons.notifications_active, label: 'Realtime SOS')),
                  ])
                ]),
              ),
            ),
          ),
        ),
      ),
    );

    return card;
  }
}

class _MiniFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white70), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white70))]),
    );
  }
}

/// Polished glass button
class GlassButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  const GlassButton({super.key, required this.label, this.icon, this.onTap, this.busy = false});

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with TickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  late final AnimationController _glow;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 160), lowerBound: 0.96, upperBound: 1.0);
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _press.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _down(_) {
    if (widget.onTap != null && !widget.busy) _press.forward();
  }

  void _up(_) {
    if (widget.onTap != null && !widget.busy) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.busy;
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: enabled ? _down : null,
          onTapUp: enabled ? _up : null,
          onTapCancel: enabled ? () => _press.reverse() : null,
          onTap: enabled ? widget.onTap : null,
          child: Transform.scale(
            scale: _scale.value,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.06)]),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                      BoxShadow(color: Colors.white.withOpacity(0.02 * _glowAnim.value), blurRadius: 30, spreadRadius: 6),
                    ],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (widget.busy)
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    else if (widget.icon != null) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 14),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.redAccent, Colors.red])),
                        child: Icon(widget.icon, color: Colors.white, size: 20),
                      )
                    ],
                    Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ---------------- Register hospital ----------------
class AdminRegisterHospitalPage extends StatefulWidget {
  final String adminUid;
  const AdminRegisterHospitalPage({required this.adminUid, super.key});

  @override
  State<AdminRegisterHospitalPage> createState() => _AdminRegisterHospitalPageState();
}

class _AdminRegisterHospitalPageState extends State<AdminRegisterHospitalPage> with TickerProviderStateMixin {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _pincode = TextEditingController();
  bool _loading = false;
  Position? _currentPosition;

  late final List<AnimationController> _fields;
  late final List<Animation<Offset>> _slides;
  late final List<Animation<double>> _fades;

  @override
  void initState() {
    super.initState();

    _fields = List.generate(5, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 520)));
    _slides = _fields.map((c) => Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack))).toList();
    _fades = _fields.map((c) => CurvedAnimation(parent: c, curve: Curves.easeIn)).toList();

    for (var i = 0; i < _fields.length; i++) {
      Timer(Duration(milliseconds: 120 * i), () {
        if (mounted) _fields[i].forward();
      });
    }

    _determinePosition();
  }

  @override
  void dispose() {
    for (final c in _fields) c.dispose();
    super.dispose();
  }

  Widget _animField({required Widget child, required int idx}) {
    return SlideTransition(position: _slides[idx], child: FadeTransition(opacity: _fades[idx], child: child));
  }

  InputDecoration _inputDec({required String label}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
    );
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location services')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = pos);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<void> _saveHospital() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final address = _address.text.trim();
    final pincode = _pincode.text.trim();
    if (name.isEmpty || phone.isEmpty || address.isEmpty || pincode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available')));
      return;
    }
    setState(() => _loading = true);
    try {
      final geo = GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);
      await FirebaseFirestore.instance.collection('hospitals').add({
        'name': name,
        'phone': phone,
        'address': address,
        'pincode': pincode,
        'location': geo,
        'adminUid': widget.adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hospital registered successfully')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard(adminUid: widget.adminUid)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _locText() {
    if (_currentPosition == null) return 'Location: fetching…';
    return 'Location: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Register Hospital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF09021F), Color(0xFF2E0261)]))),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF09021F), Color(0xFF2C0546)])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 22,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _animField(child: TextField(controller: _name, decoration: _inputDec(label: 'Hospital Name')), idx: 0),
                  const SizedBox(height: 12),
                  _animField(child: TextField(controller: _phone, decoration: _inputDec(label: 'Phone Number')), idx: 1),
                  const SizedBox(height: 12),
                  _animField(child: TextField(controller: _address, decoration: _inputDec(label: 'Address')), idx: 2),
                  const SizedBox(height: 12),
                  _animField(child: TextField(controller: _pincode, decoration: _inputDec(label: 'Pincode')), idx: 3),
                  const SizedBox(height: 18),
                  _animField(
                    idx: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(_currentPosition == null ? Icons.location_disabled : Icons.location_on, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_locText(), style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        InkWell(onTap: _determinePosition, child: const Icon(Icons.refresh, color: Colors.white)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: GlassButton(label: 'Refresh Location', icon: Icons.location_searching, onTap: _determinePosition)),
                    const SizedBox(width: 14),
                    Expanded(child: GlassButton(label: _loading ? 'Saving…' : 'Register Hospital', icon: Icons.save, onTap: _loading ? null : _saveHospital, busy: _loading)),
                  ])
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------- Admin Dashboard ----------------
class AdminDashboard extends StatefulWidget {
  final String adminUid;
  const AdminDashboard({required this.adminUid, super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  Stream<QuerySnapshot<Map<String, dynamic>>> _hospitalStream() =>
      FirebaseFirestore.instance.collection('hospitals').where('adminUid', isEqualTo: widget.adminUid).limit(1).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> _sosStream() => FirebaseFirestore.instance.collection('sos_notifications').where('adminUid', isEqualTo: widget.adminUid).orderBy('createdAt', descending: true).snapshots();

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _acknowledgeSos(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('sos_notifications').doc(docId).update({'status': 'acknowledged', 'acknowledgedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS acknowledged')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to acknowledge: $e')));
    }
  }

  Future<void> _deleteSos(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete SOS'),
        content: const Text('Are you sure you want to delete this SOS notification? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('sos_notifications').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete SOS: $e')));
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchSosFallback() async {
    final q = await FirebaseFirestore.instance.collection('sos_notifications').where('adminUid', isEqualTo: widget.adminUid).get();
    final docs = q.docs;
    docs.sort((a, b) {
      final aTs = (a.data()['createdAt'] as Timestamp?)?.toDate();
      final bTs = (b.data()['createdAt'] as Timestamp?)?.toDate();
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
    return docs;
  }

  Widget _buildSosListFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return const Center(child: Text('No SOS requests yet', style: TextStyle(color: Colors.white70, fontSize: 16)));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final d = docs[i].data();
        final user = d['userEmail'] ?? 'Unknown User';
        final loc = d['userLocation'] as GeoPoint?;
        final dist = d['distanceMeters'];
        final time = d['createdAt'] as Timestamp?;
        final status = d['status'] ?? 'sent';
        final docId = docs[i].id;
        return _AnimatedSosTile(
          delay: Duration(milliseconds: 120 * i),
          id: docId,
          user: user,
          loc: loc,
          dist: dist,
          time: _formatTimestamp(time),
          status: status,
          onAcknowledge: () => _acknowledgeSos(context, docId),
          onDelete: () => _deleteSos(context, docId),
          onOpenMap: () {
            if (loc == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available for this SOS')));
              return;
            }
            Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => AdminMapPage(lat: loc.latitude, lng: loc.longitude, userEmail: user, sosDocId: docId, heroTag: docId, onAcknowledge: () => _acknowledgeSos(context, docId), onDelete: () => _deleteSos(context, docId)), transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));
          },
        );
      },
    );
  }

  Stream<int> _unreadCountStream() {
    // count sos where status != acknowledged
    return FirebaseFirestore.instance
        .collection('sos_notifications')
        .where('adminUid', isEqualTo: widget.adminUid)
        .where('status', isNotEqualTo: 'acknowledged')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF09021F), Color(0xFF2E0261)]))),
        title: Row(children: [
          const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          StreamBuilder<int>(stream: _unreadCountStream(), builder: (context, snap) {
            final unread = snap.data ?? 0;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: unread > 0
                  ? Container(key: ValueKey('badge_$unread'), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.notification_important, color: Colors.white, size: 18), const SizedBox(width: 8), Text('$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))
                  : const SizedBox(key: ValueKey('emptyBadge'), width: 8),
            );
          }),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          })
        ]),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF09021F), Color(0xFF2C0546)])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Card(
                elevation: 20,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)])),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _hospitalStream(), builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                    if (!snap.hasData || snap.data!.docs.isEmpty) return const Text('No hospital registered yet', style: TextStyle(color: Colors.white70));
                    final data = snap.data!.docs.first.data();
                    final name = data['name'] ?? '';
                    final phone = data['phone'] ?? '';
                    final address = data['address'] ?? '';
                    final pincode = data['pincode'] ?? '';
                    final location = data['location'] as GeoPoint?;
                    return Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle), child: const Icon(Icons.local_hospital, color: Colors.white, size: 28)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Phone: $phone', style: const TextStyle(color: Colors.white70)),
                          Text('Address: $address', style: const TextStyle(color: Colors.white70)),
                          Text('Pincode: $pincode', style: const TextStyle(color: Colors.white70)),
                          if (location != null) Text('Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70)),
                        ]),
                      )
                    ]);
                  }),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.campaign, color: Colors.redAccent)), const SizedBox(width: 12), const Text('Incoming SOS Alerts', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  elevation: 18,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.02)])),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _sosStream(), builder: (context, snap) {
                      if (snap.hasError) {
                        return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(future: _fetchSosFallback(), builder: (context, fb) {
                          if (fb.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                          if (fb.hasError) return Center(child: Text('Could not load SOSs: ${fb.error}', style: const TextStyle(color: Colors.white70)));
                          final docs = fb.data ?? [];
                          return _buildSosListFromDocs(docs);
                        });
                      }
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) return const Center(child: Text('No SOS requests yet', style: TextStyle(color: Colors.white70)));
                      return _buildSosListFromDocs(docs);
                    }),
                  ),
                ),
              )
            ]),
          ),
        ),
      ),
    );
  }
}

/// Animated SOS tile
class _AnimatedSosTile extends StatefulWidget {
  final Duration delay;
  final String id;
  final String user;
  final GeoPoint? loc;
  final Object? dist;
  final String time;
  final String status;
  final VoidCallback onAcknowledge;
  final VoidCallback onDelete;
  final VoidCallback onOpenMap;

  const _AnimatedSosTile({required this.delay, required this.id, required this.user, required this.loc, required this.dist, required this.time, required this.status, required this.onAcknowledge, required this.onDelete, required this.onOpenMap, super.key});

  @override
  State<_AnimatedSosTile> createState() => _AnimatedSosTileState();
}

class _AnimatedSosTileState extends State<_AnimatedSosTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    Timer(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _statusColor(String status) => status == 'acknowledged' ? Colors.green.shade400 : Colors.redAccent;

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final distText = widget.dist != null ? '${(widget.dist as num).toStringAsFixed(0)} m' : null;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withOpacity(0.03)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onOpenMap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Hero(
                    tag: 'sos-avatar-${widget.id}',
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _statusColor(widget.status), width: 2), color: _statusColor(widget.status).withOpacity(0.12)),
                      child: Icon(Icons.sos, color: _statusColor(widget.status)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SOS — ${widget.user}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (loc != null) Text('Location: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70)),
                      if (distText != null) Text('Distance: $distText', style: const TextStyle(color: Colors.white70)),
                      Text('Time: ${widget.time}', style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    _smallIconButton(icon: Icons.check_circle_outline, color: Colors.green, onPressed: widget.status == 'acknowledged' ? null : widget.onAcknowledge),
                    const SizedBox(height: 8),
                    _smallIconButton(icon: Icons.map_outlined, color: Colors.blue, onPressed: widget.onOpenMap),
                    const SizedBox(height: 8),
                    _smallIconButton(icon: Icons.delete_outline, color: Colors.redAccent, onPressed: widget.onDelete),
                  ])
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallIconButton({required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
      child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onPressed),
    );
  }
}

/// ---------------- AdminMapPage ----------------
class AdminMapPage extends StatefulWidget {
  final double lat;
  final double lng;
  final String userEmail;
  final String sosDocId;
  final String? heroTag;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDelete;

  const AdminMapPage({required this.lat, required this.lng, required this.userEmail, required this.sosDocId, this.heroTag, this.onAcknowledge, this.onDelete, super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> with TickerProviderStateMixin {
  late final LatLng _point;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final MapController _mapController;

  late final AnimationController _fabCtrl;
  late final Animation<Offset> _fabOffset;

  double _zoom = 15.0;

  @override
  void initState() {
    super.initState();
    _point = LatLng(widget.lat, widget.lng);
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.22).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _mapController = MapController();

    _fabCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fabOffset = Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOutCubic));
    _fabCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _zoom = 16.5);
          _mapController.move(_point, _zoom);
        }
      });
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  Future<void> _openExternalMaps() async {
    final mapsWeb = 'https://www.google.com/maps/dir/?api=1&destination=${widget.lat},${widget.lng}&travelmode=driving';
    final uri = Uri.parse(mapsWeb);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: mapsWeb));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open external maps — link copied to clipboard.')));
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: mapsWeb));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open maps: $e — link copied to clipboard')));
    }
  }

  Future<void> _acknowledge() async {
    try {
      await FirebaseFirestore.instance.collection('sos_notifications').doc(widget.sosDocId).update({'status': 'acknowledged', 'acknowledgedAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS acknowledged')));
      widget.onAcknowledge?.call();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ack failed: $e')));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete SOS'),
        content: const Text('Delete this SOS notification? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('sos_notifications').doc(widget.sosDocId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS deleted')));
      widget.onDelete?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _centerMap() {
    _mapController.move(_point, 17.0);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Centered on SOS location')));
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = widget.heroTag ?? 'sos-avatar-${widget.sosDocId}';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Tracing — ${widget.userEmail}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF09021F), Color(0xFF2E0261)]))),
        actions: [IconButton(tooltip: 'Acknowledge', icon: const Icon(Icons.check_circle_outline, color: Colors.white), onPressed: _acknowledge), IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _delete)],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(center: _point, zoom: _zoom, maxZoom: 18),
          children: [
            TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'com.example.accident__tracker'),
            MarkerLayer(markers: [
              Marker(point: _point, width: 200, height: 200, builder: (ctx) {
                // Use AnimatedBuilder so both scale and opacity animate and rebuild properly
                return AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return Hero(
                      tag: heroTag,
                      child: Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: _scale.value,
                          child: Opacity(
                            opacity: _opacity.value,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.redAccent.withOpacity(0.32), Colors.redAccent.withOpacity(0.12)]), border: Border.all(color: Colors.redAccent, width: 3)),
                              child: const Icon(Icons.location_on, color: Colors.redAccent, size: 56),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              })
            ])
          ],
        ),
      ]),
      floatingActionButton: SlideTransition(
        position: _fabOffset,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton.extended(
            heroTag: 'directions',
            onPressed: _openExternalMaps,
            backgroundColor: Colors.redAccent,
            icon: const Icon(Icons.directions, color: Colors.white),
            label: const Text('Open in Maps', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'center',
            onPressed: _centerMap,
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
