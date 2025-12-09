import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/community/presentation/pages/community_screen.dart';
import 'package:study_sensei/features/auth/presentation/pages/profile_screen.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/sensei/screens/sensei_landing_screen.dart';
import 'package:study_sensei/features/sensei/screens/satori_agent_screen.dart';
import 'package:study_sensei/features/home/data/repositories/home_repository.dart';
import 'package:study_sensei/features/home/presentation/controller/home_view_model.dart';
import 'package:study_sensei/features/home/presentation/pages/home_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  late final List<Widget> _screens = [];
  late String _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserProvider>(context, listen: true).user;
    if (user == null || user.uid.isEmpty) {
      // Handle case where user is not available
      return;
    }

    _userId = user.uid;

    // Initialize screens with required dependencies
    if (_screens.isEmpty) {
      _screens.addAll([
        ChangeNotifierProvider(
          key: const ValueKey('home-screen'),
          create: (_) => HomeViewModel(
            repository: HomeRepository(),
            userId: _userId,
          ),
          child: const HomeScreen(),
        ),
        const SatoriAgentScreen(),
        CommunityScreen(userId: _userId),
        const SenseiLandingScreen(),
        const ProfileScreen(),
      ]);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    // If on the first tab, minimize the app
    if (_currentIndex == 0) {
      return false; // Let system handle the back button (minimize app)
    }
    // If on any other tab, switch to the first tab
    setState(() {
      _currentIndex = 0;
    });
    return false; // Don't exit the app
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Bottom navigation items
  List<BottomNavigationBarItem> get _bottomNavItems => [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.monitor_heart_rounded),
          label: 'Satori',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_rounded),
          label: 'Community',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.school_rounded),
          label: 'Sensei',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                items: _bottomNavItems,
                selectedItemColor: Theme.of(context).primaryColor,
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
