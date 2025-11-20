import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class PhoneVerificationScreen extends StatefulWidget {
  static const routeName = '/verify-phone';

  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _codeSent = false;
  String? _statusMessage;
  bool _isStatusError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() {
        _statusMessage = 'Enter a phone number including the country code.';
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _statusMessage = null;
      _isStatusError = false;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: rawPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          await _linkCredential(credential, rawPhone);
        },
        verificationFailed: (e) {
          setState(() {
            _statusMessage = e.message ?? 'Failed to send verification code.';
            _isSendingCode = false;
            _isStatusError = true;
          });
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isSendingCode = false;
            _statusMessage = 'Code sent. Enter the 6-digit code to verify.';
            _isStatusError = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Unable to send code. Please try again.';
        _isSendingCode = false;
        _isStatusError = true;
      });
    }
  }

  Future<void> _verifyCode() async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      setState(() {
        _statusMessage = 'Send the code first.';
        _isStatusError = true;
      });
      return;
    }

    final smsCode = _codeController.text.trim();
    if (smsCode.length < 6) {
      setState(() {
        _statusMessage = 'Enter the 6-digit verification code.';
        _isStatusError = true;
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _statusMessage = null;
      _isStatusError = false;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _linkCredential(credential, _phoneController.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() {
        _statusMessage = e.message ?? 'The code is invalid. Please try again.';
        _isVerifyingCode = false;
        _isStatusError = true;
      });
    }
  }

  Future<void> _linkCredential(
    PhoneAuthCredential credential,
    String phoneNumber,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'You need to be signed in to verify your phone.';
        _isSendingCode = false;
        _isVerifyingCode = false;
        _isStatusError = true;
      });
      return;
    }

    try {
      if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
        await user.linkWithCredential(credential);
      } else {
        await user.updatePhoneNumber(credential);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        setState(() {
          _statusMessage = 'This phone number is already linked to another account.';
          _isSendingCode = false;
          _isVerifyingCode = false;
          _isStatusError = true;
        });
        return;
      } else if (e.code == 'provider-already-linked') {
        await user.updatePhoneNumber(credential);
      } else {
        setState(() {
          _statusMessage = e.message ?? 'Failed to verify phone number.';
          _isSendingCode = false;
          _isVerifyingCode = false;
          _isStatusError = true;
        });
        return;
      }
    }

    await _saveVerifiedPhone(phoneNumber);
  }

  Future<void> _saveVerifiedPhone(String phoneNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('userPreferences')
          .doc(user.uid)
          .set(
        {
          'phone': phoneNumber,
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'phone': phoneNumber,
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        await context.read<UserProvider>().refreshUserPreferences();
        setState(() {
          _statusMessage = 'Phone number verified successfully.';
          _isSendingCode = false;
          _isVerifyingCode = false;
          _isStatusError = false;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Verification succeeded but we could not save the status.';
        _isSendingCode = false;
        _isVerifyingCode = false;
        _isStatusError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSendingCode || _isVerifyingCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Phone'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a phone number',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a phone number with the country code (for example, +1 555 123 4567). We will send you a verification code to unlock AI features.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              enabled: !_codeSent,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_codeSent)
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Verification code',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isStatusError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: isBusy ? null : (_codeSent ? _verifyCode : _sendCode),
                  child: isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_codeSent ? 'Verify Code' : 'Send Code'),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: isBusy ? null : _sendCode,
                    child: const Text('Resend Code'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
