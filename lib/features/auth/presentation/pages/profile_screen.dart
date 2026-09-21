import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:study_sensei/core/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/features/common/services/media_picker_service.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';
import 'package:study_sensei/features/friends/data/repositories/friend_repository_impl.dart';
import 'package:study_sensei/features/friends/domain/repositories/friend_repository.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';
import 'profile_view.dart';
import '../../models/user_preferences.dart';
import '../../providers/user_provider.dart';
import 'pending_requests_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    _loadPendingRequests();
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
      final ref =
          _storage.ref().child('profile_pictures/${user.uid}.$extension');
      await ref.putData(picked.bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      if (!mounted) return;
      await context
          .read<UserProvider>()
          .updatePreferences(photoUrl: downloadUrl);
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

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await PushNotificationService.instance.unregisterDevice();
      await FirebaseAuth.instance.signOut();
      await userProvider.signOut();
      // The auth listener may unmount Profile before sign-out completes.
      // Use the captured root navigator to remove authenticated routes safely.
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil('/', (route) => false);
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
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

    return ProfileView(
      photoUrl: profilePhotoUrl,
      name: userData?.name ?? user?.displayName ?? 'Sensei Learner',
      email: userData?.email ?? user?.email ?? '',
      notificationsEnabled: userData?.notificationsEnabled,
      isPhotoUpdating: _updatingPhoto,
      onEditProfile: () => _openEditProfile(user, userData),
      onSignOut: () => _signOut(context),
      onChangePhoto: _changeProfilePhoto,
      requests: PendingRequestsCard(
        loading: _requestsLoading,
        requests: _pendingRequests,
        onAccept: _acceptRequest,
        onDecline: _declineRequest,
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
    _selectedGender =
        prefGender != null && prefGender.isNotEmpty ? prefGender : null;
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
                  tooltip: 'Close edit profile',
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
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
              isExpanded: true,
              initialValue: _selectedGender,
              items: _genderOptions
                  .map(
                    (gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender, overflow: TextOverflow.ellipsis)),
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
            SenseiPrimaryButton(
              onPressed: _saving ? null : _saveProfile,
              isLoading: _saving,
              text: 'Save changes',
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
    if (picked != null && mounted) {
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
