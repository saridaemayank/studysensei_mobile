import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../community/presentation/pages/community_screen.dart';
import '../../auth/presentation/pages/profile_screen.dart';
import '../../auth/providers/user_provider.dart';
import '../widgets/sensei_bottom_navigation.dart';
import '../../sensei/screens/sensei_landing_screen.dart';
import '../../focus/screens/focus_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 0});

  /// Reset only the Sensei tab after completing a Doubt flow.
  static void showDoubt(BuildContext context) {
    context.findAncestorStateOfType<_MainLayoutState>()?._showDoubt();
  }

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  int _senseiGeneration = 0;
  bool _focusActive = false;
  void _showDoubt() => setState(() {
        _currentIndex = 0;
        _senseiGeneration++;
      });
  String? _userId;
  Widget? _dojos;
  Widget? _profile;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<UserProvider?>()?.user?.uid;
    if (_userId != userId) {
      _userId = userId;
      _dojos = null;
      _profile = null;
    }
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Create authenticated tabs only when visited; preserve their state afterward.
    if (_currentIndex == 2 && _userId != null) {
      _dojos ??= CommunityScreen(userId: _userId!);
    }
    if (_currentIndex == 3 && _userId != null) {
      _profile ??= const ProfileScreen();
    }
    final navigation = _currentIndex == 1 && _focusActive
        ? const SizedBox.shrink()
        : SenseiBottomNavigation(
            currentIndex: _currentIndex, onTap: _onItemTapped);
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: [
          SenseiLandingScreen(key: ValueKey(_senseiGeneration)),
          TickerMode(
              enabled: _currentIndex == 1,
              child: NotificationListener<FocusActivityNotification>(
                  onNotification: (event) {
                    if (_focusActive != event.active) {
                      setState(() => _focusActive = event.active);
                    }
                    return true;
                  },
                  child: const FocusScreen())),
          _dojos ?? const SizedBox.shrink(),
          _profile ?? const SizedBox.shrink(),
        ]),
        bottomNavigationBar: MediaQuery.disableAnimationsOf(context)
            ? navigation
            : AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: navigation),
      ),
    );
  }
}
