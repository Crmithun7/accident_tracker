// lib/pages/user_admin_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// USER HOME - simple profile + logout
class UserHome extends StatelessWidget {
  final String uid;
  const UserHome({required this.uid, super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>> _getProfile() {
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Home'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Profile not found'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      // optional: create a fallback profile
                      final user = auth.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                          'email': user.email ?? '',
                          'role': 'user',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }
                    },
                    child: const Text('Create Profile'),
                  ),
                ],
              ),
            );
          }

          final data = doc.data()!;
          final email = data['email'] ?? auth.currentUser?.email ?? 'no-email';
          final role = data['role'] ?? 'user';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Email: $email'),
                const SizedBox(height: 6),
                Text('Role: $role'),
                const SizedBox(height: 20),
                const Text('User-specific content goes here...'),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ADMIN HOME - list all users and let admin change role (dev/testing)
class AdminHome extends StatelessWidget {
  final String uid;
  const AdminHome({required this.uid, super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: false).snapshots();
  }

  Future<void> _changeRole(BuildContext context, String targetUid, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'user' : 'admin';

    // confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm role change'),
        content: Text('Change role to "$newRole" for this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({'role': newRole});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role updated to $newRole')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update role: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(child: Text('Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ElevatedButton.icon(
                  onPressed: () async {
                    // quick helper: create a test user doc if needed (dev)
                    final user = auth.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'email': user.email ?? '',
                        'role': 'admin',
                        'createdAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile ensured')));
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Ensure Profile'),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                final docs = snap.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final email = data['email'] ?? 'no-email';
                    final role = data['role'] ?? 'user';
                    final docUid = doc.id;

                    // Don't allow admin to change their own role from this UI accidentally
                    final disableChangeSelf = docUid == uid;

                    return ListTile(
                      title: Text(email),
                      subtitle: Text('Role: $role'),
                      leading: role == 'admin' ? const Icon(Icons.shield) : const Icon(Icons.person),
                      trailing: disableChangeSelf
                          ? const Text('(you)')
                          : TextButton(
                              onPressed: () => _changeRole(context, docUid, role),
                              child: Text(role == 'admin' ? 'Demote' : 'Promote'),
                            ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: const [
                Text(
                  'Security note: Changing roles from the client is only for development/testing. '
                  'In production, use a trusted server/Admin SDK or Cloud Function to set roles/custom claims '
                  'and secure Firestore rules so clients cannot assign themselves admin.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
