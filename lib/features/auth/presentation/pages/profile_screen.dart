import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_sensei/features/auth/login/screens/login_screen.dart';
import 'package:study_sensei/features/common/services/media_picker_service.dart';
import 'package:study_sensei/features/common/widgets/premium_celebration_overlay.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';
import 'package:study_sensei/features/friends/data/repositories/friend_repository_impl.dart';
import 'package:study_sensei/features/friends/domain/repositories/friend_repository.dart';
import '../../models/user_preferences.dart';
import '../../providers/user_provider.dart';
import 'pending_requests_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Duration _freeWeeklyAllowance = Duration(minutes: 5);
  static const Duration _premiumWeeklyAllowance = Duration(minutes: 15);
  Duration _activeWeeklyAllowance = _freeWeeklyAllowance;
  Duration? _remainingWeeklyUsage;
  bool _usageLoading = true;
  bool _premiumCelebrationShown = false;
  DateTime? _nextReset;
  static const String _subscriptionProductId = 'sensei_pro_monthly';
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _storeAvailable = false;
  bool _purchasePending = false;
  bool _hasActiveSubscription = false;
  String? _purchaseError;
  List<ProductDetails> _availableProducts = [];
  final FriendRepository _friendRepository = FriendRepositoryImpl();
  List<FriendRequestModel> _pendingRequests = [];
  bool _requestsLoading = true;
  final MediaPickerService _mediaPicker = MediaPickerService();
  bool _updatingPhoto = false;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUsageInfo();
    _loadPendingRequests();
    _initializeInAppPurchase();
  }

  Future<void> _loadUsageInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    final userProvider = context.read<UserProvider>();
    final subscriptionPlan =
        userProvider.userPreferences?.subscriptionPlan.toLowerCase() ?? 'free';
    final isProUser = subscriptionPlan == 'premium';
    final planAllowance = isProUser
        ? _premiumWeeklyAllowance
        : _freeWeeklyAllowance;
    final currentPlan = isProUser ? 'premium' : 'free';

    Duration remaining = planAllowance;
    DateTime nextResetUtc = _weekStart(
      DateTime.now().toUtc(),
    ).add(const Duration(days: 7));
    final userId = user?.uid;
    if (userId != null) {
      final weekKey = 'satori_week_start_$userId';
      final remainingKey = 'satori_week_seconds_$userId';
      final planKey = 'satori_week_plan_$userId';
      final storedWeek = prefs.getInt(weekKey);
      final storedSeconds = prefs.getInt(remainingKey);
      final storedPlan = prefs.getString(planKey);
      final nowUtc = DateTime.now().toUtc();
      final currentWeekStart = _weekStart(nowUtc);
      final currentWeekEpoch = currentWeekStart.millisecondsSinceEpoch;

      if (storedWeek != null) {
        final storedWeekStart = DateTime.fromMillisecondsSinceEpoch(
          storedWeek,
          isUtc: true,
        );
        final storedNextReset = storedWeekStart.add(const Duration(days: 7));

        if (storedNextReset.isBefore(nowUtc)) {
          await prefs.setInt(weekKey, currentWeekEpoch);
          await prefs.setInt(remainingKey, planAllowance.inSeconds);
          await prefs.setString(planKey, currentPlan);
          remaining = planAllowance;
          nextResetUtc = currentWeekStart.add(const Duration(days: 7));
        } else {
          var effectiveSeconds = storedSeconds ?? planAllowance.inSeconds;
          if (effectiveSeconds < 0) effectiveSeconds = 0;

          final freeAllowanceSeconds = _freeWeeklyAllowance.inSeconds;
          final premiumAllowanceSeconds = _premiumWeeklyAllowance.inSeconds;
          final planChanged = storedPlan != null && storedPlan != currentPlan;

          if (planChanged) {
            if (currentPlan == 'premium' && storedPlan == 'free') {
              final usedSeconds = _clampInt(
                freeAllowanceSeconds - effectiveSeconds,
                0,
                freeAllowanceSeconds,
              );
              effectiveSeconds = _clampInt(
                premiumAllowanceSeconds - usedSeconds,
                0,
                premiumAllowanceSeconds,
              );
            } else if (currentPlan == 'free' && storedPlan == 'premium') {
              effectiveSeconds = _clampInt(
                effectiveSeconds,
                0,
                freeAllowanceSeconds,
              );
            }
          }

          if (isProUser) {
            effectiveSeconds = _clampInt(
              effectiveSeconds,
              0,
              premiumAllowanceSeconds,
            );
          } else {
            effectiveSeconds = _clampInt(
              effectiveSeconds,
              0,
              freeAllowanceSeconds,
            );
          }

          if (storedSeconds != null && effectiveSeconds != storedSeconds) {
            await prefs.setInt(remainingKey, effectiveSeconds);
          }
          if (planChanged || storedPlan == null) {
            await prefs.setString(planKey, currentPlan);
          }

          remaining = Duration(seconds: effectiveSeconds);
          nextResetUtc = storedNextReset;
        }
      } else {
        await prefs.setInt(weekKey, currentWeekEpoch);
        await prefs.setInt(remainingKey, planAllowance.inSeconds);
        await prefs.setString(planKey, currentPlan);
        remaining = planAllowance;
        nextResetUtc = currentWeekStart.add(const Duration(days: 7));
      }
    }

    if (!mounted) return;
    setState(() {
      _remainingWeeklyUsage = remaining;
      _activeWeeklyAllowance = planAllowance;
      _nextReset = nextResetUtc.toLocal();
      _usageLoading = false;
    });
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _requestsLoading = true);
    try {
      final requests = await _friendRepository.getFriendRequests();
      if (!mounted) return;
      setState(() {
        _pendingRequests = requests;
      });
    } catch (e) {
      debugPrint('Failed to load pending requests: $e');
      if (mounted) {
        _showSnackBar('Could not load pending requests.');
      }
    } finally {
      if (mounted) {
        setState(() => _requestsLoading = false);
      }
    }
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Future<void> _initializeInAppPurchase() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!mounted) return;

    setState(() {
      _storeAvailable = available;
    });

    if (!available) {
      _purchaseError = 'Store unavailable. Please try again later.';
      return;
    }

    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _purchaseSubscription?.cancel();
        _purchaseSubscription = null;
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _purchaseError = 'Purchase failed: $error';
          _purchasePending = false;
        });
      },
    );

    await _loadProducts();
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails({_subscriptionProductId});
    if (!mounted) return;

    if (response.error != null) {
      setState(() {
        _purchaseError = response.error!.message;
      });
    } else {
      setState(() {
        _purchaseError = null;
      });
    }

    if (response.notFoundIDs.isNotEmpty && mounted) {
      setState(() {
        _purchaseError =
            'Product not found: ${response.notFoundIDs.join(', ')}';
      });
    }

    setState(() {
      _availableProducts = response.productDetails;
    });
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      await _processPurchaseDetails(purchaseDetails);
    }
  }

  Future<void> _processPurchaseDetails(PurchaseDetails purchaseDetails) async {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        if (!mounted) return;
        setState(() {
          _purchasePending = true;
          _purchaseError = null;
          _premiumCelebrationShown = false;
        });
        break;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final bool valid = await _verifyPurchase(purchaseDetails);
        if (valid && mounted) {
          final userProvider = context.read<UserProvider>();
          final bool wasPremiumBeforeProcessing = _hasActiveSubscription ||
              (userProvider.userPreferences?.subscriptionPlan.toLowerCase() ==
                  'premium');
          setState(() {
            _hasActiveSubscription = true;
            _purchasePending = false;
            _purchaseError = null;
          });
          _showSnackBar('Subscription activated.');
          await _updateSubscriptionPlan('premium');
          final bool gainedPremiumWhileClosed =
              purchaseDetails.status == PurchaseStatus.restored &&
                  !wasPremiumBeforeProcessing;
          if (purchaseDetails.status == PurchaseStatus.purchased ||
              gainedPremiumWhileClosed) {
            _triggerPremiumCelebration();
          }
        } else if (!valid && mounted) {
          setState(() {
            _purchaseError = 'Purchase verification failed.';
            _purchasePending = false;
          });
          _showSnackBar('Purchase could not be verified.');
        }
        break;
      case PurchaseStatus.canceled:
        if (!mounted) return;
        setState(() {
          _purchasePending = false;
          _purchaseError = 'Purchase cancelled.';
        });
        _showSnackBar('Purchase cancelled.');
        break;
      case PurchaseStatus.error:
        if (!mounted) return;
        setState(() {
          _purchasePending = false;
          _purchaseError =
              purchaseDetails.error?.message ??
              'An error occurred during the purchase.';
        });
        _showSnackBar('Purchase failed.');
        break;
    }

    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Implement secure server-side receipt validation.
    return purchaseDetails.productID == _subscriptionProductId;
  }

  Future<void> _updateSubscriptionPlan(String plan) async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.updateSubscriptionPlan(plan);
    } catch (e) {
      debugPrint('Failed to update subscription plan: $e');
    }
  }

  void _triggerPremiumCelebration() {
    if (_premiumCelebrationShown || !mounted) return;
    setState(() {
      _premiumCelebrationShown = true;
    });

    Future.microtask(() {
      if (!mounted) return;
      showPremiumCelebrationOverlay(
        context,
        texts: (
          title: 'Your journey just leveled up! 🚀',
          subtitle: 'Enjoy premium access to Sensei, Satori, and more.',
        ),
      );
    });
  }

  Future<void> _onUpgradePressed() async {
    if (_purchasePending) return;

    if (!_storeAvailable) {
      _showSnackBar('Store not available. Please try again later.');
      return;
    }

    if (_availableProducts.isEmpty) {
      await _loadProducts();
      if (_availableProducts.isEmpty) {
        _showSnackBar('Unable to load subscription details.');
        return;
      }
    }

    final ProductDetails product = _availableProducts.first;
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null,
    );

    setState(() {
      _purchasePending = true;
      _purchaseError = null;
    });

    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
        _purchaseError = 'Unable to start purchase: $e';
      });
      _showSnackBar('Something went wrong. Please try again.');
    }
  }

  Future<void> _onManagePlanPressed() async {
    if (_purchasePending) return;
    setState(() {
      _purchasePending = true;
      _purchaseError = null;
    });
    try {
      await _inAppPurchase.restorePurchases();
      _showSnackBar('Restoring purchases...');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchaseError = 'Could not restore purchases: $e';
      });
      _showSnackBar('Could not restore purchases.');
    } finally {
      if (mounted) {
        setState(() {
          _purchasePending = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeProfilePhoto() async {
    if (_updatingPhoto) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picked = await _mediaPicker.pickProfilePhoto();
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _updatingPhoto = true);

      final extension = _resolveFileExtension(picked.fileName);
      final metadata = SettableMetadata(
        contentType: _contentTypeForExtension(extension),
      );
      final ref = _storage.ref().child('profile_pictures/${user.uid}.$extension');
      await ref.putData(picked.bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await context.read<UserProvider>().updatePreferences(photoUrl: downloadUrl);
      await _firestore.collection('users').doc(user.uid).set(
        {
          'photoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _showSnackBar('Profile photo updated.');
    } catch (e) {
      debugPrint('Failed to update profile photo: $e');
      _showSnackBar('Could not update profile photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _updatingPhoto = false);
      }
    }
  }

  String _resolveFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'jpg';
    final ext = parts.last.toLowerCase();
    return ext.isEmpty ? 'jpg' : ext;
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    try {
      await _friendRepository.respondToFriendRequest(
        requestId: request.requestId,
        isAccepted: true,
        senderId: request.senderId,
      );
      if (!mounted) return;
      setState(() {
        _pendingRequests = _pendingRequests
            .where((r) => r.requestId != request.requestId)
            .toList();
      });
      _showSnackBar('Accepted request from ${request.senderName}.');
    } catch (e) {
      debugPrint('Failed to accept request: $e');
      _showSnackBar('Could not accept the request. Please try again.');
    }
  }

  Future<void> _declineRequest(FriendRequestModel request) async {
    try {
      await _friendRepository.respondToFriendRequest(
        requestId: request.requestId,
        isAccepted: false,
        senderId: request.senderId,
      );
      if (!mounted) return;
      setState(() {
        _pendingRequests = _pendingRequests
            .where((r) => r.requestId != request.requestId)
            .toList();
      });
      _showSnackBar('Declined request from ${request.senderName}.');
    } catch (e) {
      debugPrint('Failed to decline request: $e');
      _showSnackBar('Could not decline the request. Please try again.');
    }
  }

  DateTime _weekStart(DateTime utcNow) {
    final midnight = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final daysFromMonday = (midnight.weekday - DateTime.monday) % 7;
    return midnight.subtract(Duration(days: daysFromMonday));
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      if (context.mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.signOut();
      }
      await FirebaseAuth.instance.signOut();
      await Future.delayed(const Duration(milliseconds: 300));
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
          const SnackBar(content: Text('Error signing out. Please try again.')),
        );
      }
    }
  }

  Future<void> _openEditProfile(
    User? user,
    UserPreferences? preferences,
  ) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(user: user, preferences: preferences),
    );

    if (updated == true) {
      _showSnackBar('Profile updated successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userProvider = context.watch<UserProvider>();
    final userData = userProvider.userPreferences;

    final profilePhotoUrl = (userData?.photoUrl?.isNotEmpty ?? false)
        ? userData!.photoUrl
        : (user?.photoURL?.isNotEmpty ?? false)
        ? user!.photoURL
        : null;

    final plan = userData?.subscriptionPlan.toLowerCase() ?? 'free';
    final isProUser = plan == 'premium';
    final effectiveProStatus = isProUser || _hasActiveSubscription;
    final premiumPrice = _availableProducts.isNotEmpty
        ? _availableProducts.first.price
        : '₹ 199 / month';

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileHeaderCard(
              photoUrl: profilePhotoUrl,
              name: userData?.name ?? user?.displayName ?? 'Sensei Learner',
              email: userData?.email ?? user?.email ?? 'No email linked',
              phone: userData?.phone ?? 'Add a phone number',
              dob: userData?.dateOfBirth ?? 'Add your birthday',
              gender: userData?.gender ?? 'Let us know how to address you',
              onEditProfile: () => _openEditProfile(user, userData),
              onSignOut: () => _signOut(context),
              onChangePhoto: _changeProfilePhoto,
              isPhotoUpdating: _updatingPhoto,
            ),
            const SizedBox(height: 24),
            const Text(
              'Upgrade to Premium',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Free Plan',
              subtitle: 'For casual learners',
              features: const [
                '2 Sensei sessions/week',
                'Access to Dojos & assignments',
                'Community chat',
                'Satori (voice AI) · 5 min/week',
              ],
              isCurrentPlan: !isProUser,
              accentColor: Colors.green,
              priceLabel: 'Current Plan',
              ctaLabel: 'Included',
              onPressed: null,
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Sensei Pro',
              subtitle: 'Unlock your full potential',
              features: const [
                'Unlimited Sensei sessions',
                'Satori (voice AI) · 15 min/week',
                'AI Doubt Solver with voice chat',
                'Priority chat & early access',
                'Ad-free experience',
              ],
              isCurrentPlan: effectiveProStatus,
              accentColor: Colors.purple,
              priceLabel: premiumPrice,
              ctaLabel: _purchasePending
                  ? 'Processing...'
                  : effectiveProStatus
                  ? 'Manage Plan'
                  : 'Upgrade Now',
              onPressed: _purchasePending
                  ? null
                  : effectiveProStatus
                  ? _onManagePlanPressed
                  : _onUpgradePressed,
            ),
            if (_purchaseError != null) ...[
              const SizedBox(height: 12),
              Text(
                _purchaseError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              'Pending Friend Requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            PendingRequestsCard(
              loading: _requestsLoading,
              requests: _pendingRequests,
              onAccept: _acceptRequest,
              onDecline: _declineRequest,
            ),
            const SizedBox(height: 32),
            _WeeklyUsageCard(
              isProUser: isProUser,
              remainingDuration: _remainingWeeklyUsage,
              usageLoading: _usageLoading,
              totalAllowance: _activeWeeklyAllowance,
              nextReset: _nextReset,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final User? user;
  final UserPreferences? preferences;

  const _EditProfileSheet({required this.user, required this.preferences});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dobController;
  late final List<String> _genderOptions;
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefs = widget.preferences;
    _nameController = TextEditingController(
      text: prefs?.name ?? widget.user?.displayName ?? '',
    );
    _emailController = TextEditingController(
      text: prefs?.email ?? widget.user?.email ?? '',
    );
    _phoneController = TextEditingController(text: prefs?.phone ?? '');
    _dobController = TextEditingController(text: prefs?.dateOfBirth ?? '');
    _selectedDate = DateTime.tryParse(_dobController.text);
    final prefGender = prefs?.gender?.trim();
    _genderOptions = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
    if (prefGender != null &&
        prefGender.isNotEmpty &&
        !_genderOptions.contains(prefGender)) {
      _genderOptions.insert(0, prefGender);
    }
    _selectedGender = prefGender != null && prefGender.isNotEmpty
        ? prefGender
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit Profile',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Email changes require support assistance',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dobController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _saving ? null : _pickDate,
                ),
              ),
              onTap: _saving ? null : _pickDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              items: _genderOptions
                  .map(
                    (gender) =>
                        DropdownMenuItem(value: gender, child: Text(gender)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _selectedGender = value);
                    },
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initialDate = _selectedDate != null
        ? _selectedDate!.isAfter(now)
              ? now
              : _selectedDate!
        : DateTime(now.year - 16, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final userProvider = context.read<UserProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final dob = _dobController.text.trim();
    final gender = (_selectedGender ?? '').trim();

    try {
      await userProvider.updatePreferences(
        name: name,
        phone: phone,
        dateOfBirth: dob,
        gender: gender,
      );
      final firebaseUser = widget.user;
      if (firebaseUser != null && name.isNotEmpty) {
        await firebaseUser.updateDisplayName(name);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile. Please try again.'),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final String email;
  final String phone;
  final String dob;
  final String gender;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;
  final VoidCallback onChangePhoto;
  final bool isPhotoUpdating;

  const _ProfileHeaderCard({
    required this.photoUrl,
    required this.name,
    required this.email,
    required this.phone,
    required this.dob,
    required this.gender,
    required this.onEditProfile,
    required this.onSignOut,
    required this.onChangePhoto,
    required this.isPhotoUpdating,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _ProfileAvatar(photoUrl: photoUrl),
              Positioned(
                bottom: 4,
                right: 8,
                child: Material(
                  shape: const CircleBorder(),
                  color: Colors.white,
                  child: IconButton(
                    tooltip: 'Update photo',
                    onPressed: isPhotoUpdating ? null : onChangePhoto,
                    iconSize: 20,
                    constraints: const BoxConstraints(
                      minHeight: 36,
                      minWidth: 36,
                    ),
                    icon: isPhotoUpdating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(icon: Icons.person, value: name),
          _DetailRow(icon: Icons.email_outlined, value: email),
          _DetailRow(icon: Icons.phone_outlined, value: phone),
          _DetailRow(icon: Icons.cake_outlined, value: dob),
          _DetailRow(icon: Icons.wc_outlined, value: gender),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onEditProfile,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSignOut,
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;

  const _ProfileAvatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.purpleAccent, Colors.blueAccent, Colors.cyanAccent];

    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
      ),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: photoUrl != null
              ? Image.network(photoUrl!, fit: BoxFit.cover)
              : const Icon(
                  Icons.person_outline,
                  size: 56,
                  color: Colors.deepPurple,
                ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _DetailRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> features;
  final bool isCurrentPlan;
  final Color accentColor;
  final String priceLabel;
  final String ctaLabel;
  final VoidCallback? onPressed;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.isCurrentPlan,
    required this.accentColor,
    required this.priceLabel,
    required this.ctaLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: isCurrentPlan ? 0.4 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  priceLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(feature, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentPlan ? null : onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: accentColor.withValues(
                  alpha: isCurrentPlan ? 0.35 : 1.0,
                ),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                isCurrentPlan ? 'Current Plan' : ctaLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyUsageCard extends StatelessWidget {
  final bool isProUser;
  final Duration? remainingDuration;
  final Duration totalAllowance;
  final bool usageLoading;
  final DateTime? nextReset;

  const _WeeklyUsageCard({
    required this.isProUser,
    required this.remainingDuration,
    required this.totalAllowance,
    required this.usageLoading,
    required this.nextReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowanceSeconds = totalAllowance.inSeconds;
    final remainingSeconds =
        remainingDuration?.inSeconds ?? totalAllowance.inSeconds;
    var usedSeconds = allowanceSeconds - remainingSeconds;
    if (usedSeconds < 0) usedSeconds = 0;
    if (usedSeconds > allowanceSeconds) usedSeconds = allowanceSeconds;
    final usageFraction = allowanceSeconds == 0
        ? 0.0
        : usedSeconds / allowanceSeconds;
    final normalizedUsage = usageFraction.clamp(0.0, 1.0).toDouble();
    final usedDuration = Duration(seconds: usedSeconds);

    String usageLabel;
    if (usageLoading) {
      usageLabel = 'Loading…';
    } else if (remainingDuration == null) {
      usageLabel =
          '${_formatDurationShort(usedDuration)} used · ${_formatDurationShort(totalAllowance)} weekly';
    } else {
      usageLabel =
          '${_formatDurationShort(remainingDuration!)} left · ${_formatDurationShort(totalAllowance)} weekly';
    }
    final localizations = MaterialLocalizations.of(context);
    final countdownText = _buildCountdownText(nextReset);
    final scheduleText = _buildScheduleText(nextReset, localizations);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Weekly Usage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              children: const [
                TextSpan(
                  text: ' · Satori',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Allowance',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                usageLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!isProUser) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: usageLoading ? null : normalizedUsage,
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            countdownText,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scheduleText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Usage resets automatically every Monday.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _buildCountdownText(DateTime? nextReset) {
    if (nextReset == null) {
      return 'Reset schedule unavailable';
    }
    final diff = nextReset.difference(DateTime.now());
    if (diff.isNegative) {
      return 'Resets shortly';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) {
      parts.add('$days day${days == 1 ? '' : 's'}');
    }
    if (hours > 0) {
      parts.add('$hours hr${hours == 1 ? '' : 's'}');
    }
    if (minutes > 0 || parts.isEmpty) {
      parts.add('$minutes min${minutes == 1 ? '' : 's'}');
    }
    return 'Resets in ${parts.join(' ')}';
  }

  String _buildScheduleText(
    DateTime? nextReset,
    MaterialLocalizations localizations,
  ) {
    if (nextReset == null) {
      return 'Next reset time unavailable';
    }
    final date = localizations.formatFullDate(nextReset);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(nextReset),
      alwaysUse24HourFormat: false,
    );
    return 'Next reset on $date at $time';
  }

  String _formatDurationShort(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
