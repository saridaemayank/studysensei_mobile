import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/pages/phone_verification_screen.dart';
import '../../auth/providers/user_provider.dart';
import '../services/backend_service.dart';
import 'satori_agent_tab.dart';

class SatoriAgentScreen extends StatelessWidget {
  const SatoriAgentScreen({super.key});

  static const String _defaultSubject = 'General Studies';
  static const String _defaultConcept = 'Ask me anything';

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please sign in to start a session with Satori.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isPhoneVerified =
        userProvider.userPreferences?.phoneVerified ?? false;
    if (!isPhoneVerified) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildTabAppBar('Satori'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify your phone number',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'For everyone\'s safety, a quick phone verification is required before chatting with Satori.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context)
                        .pushNamed(PhoneVerificationScreen.routeName);
                  },
                  child: const Text('Verify Phone Number'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final backendService = BackendService(user: user);
    final subscriptionPlan =
        userProvider.userPreferences?.subscriptionPlan.toLowerCase() ?? 'free';
    final isProUser = subscriptionPlan == 'premium';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildTabAppBar('Satori'),
      body: SafeArea(
        child: SatoriAgentTab(
          backendService: backendService,
          subject: _defaultSubject,
          concept: _defaultConcept,
          isProUser: isProUser,
        ),
      ),
    );
  }

  AppBar _buildTabAppBar(String title) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.orange[100],
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'DancingScript',
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
    );
  }
}
