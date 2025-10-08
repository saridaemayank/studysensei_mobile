import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/friends/presentation/pages/friend_requests_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    try {
      // Clear any user data in the provider first
      if (context.mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.signOut();
      }

      // Then sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Ensure all Firebase operations are complete before navigating
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to login screen and remove all previous routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Sign out error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userProvider = Provider.of<UserProvider>(context);
    final userData = userProvider.userPreferences;
    
    // Debug print to check user data
    debugPrint('User Data: ${userData?.toMap().toString()}');

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.2),
                child: Text(
                  user?.displayName?.isNotEmpty == true
                      ? user!.displayName![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 48,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'Account Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person, 'Name', userData?.name ?? user?.displayName ?? 'Not set'),
            _buildInfoRow(Icons.email, 'Email', userData?.email ?? user?.email ?? 'Not set'),
            _buildInfoRow(Icons.phone, 'Phone', userData?.phone ?? 'Not set'),
            _buildInfoRow(Icons.cake, 'Date of Birth', userData?.dateOfBirth?.toString() ?? 'Not set'),
            _buildInfoRow(Icons.person_outline, 'Gender', userData?.gender?.toString() ?? 'Not set'),
            const SizedBox(height: 30),
            Center(
              child: TextButton(
                child: Text('Pending Friend Requests'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FriendRequestsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
