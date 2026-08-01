import 'package:flutter/material.dart';
import 'package:brisconnect/services/phone_auth_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';

/// Reusable phone-verification dialog.
///
/// Sends a Firebase Phone Auth code to [phone] when first built, then waits
/// for the user to enter the SMS code. Pops with `true` if verified,
/// `false` if cancelled, and `null` if dismissed.
class PhoneVerificationDialog extends StatefulWidget {
  const PhoneVerificationDialog({
    super.key,
    required this.phone,
  });

  final String phone;

  @override
  State<PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  final _codeController = TextEditingController();
  bool _isSending = true;
  bool _isVerifying = false;
  String? _statusMessage;
  InlineStatusType _statusType = InlineStatusType.error;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    final result = await PhoneAuthService.sendCodeToPhone(widget.phone);

    if (!mounted) return;
    setState(() => _isSending = false);

    switch (result) {
      case PhoneAuthSendResult.codeSent:
        setState(() {
          _statusMessage = 'Code sent to ${widget.phone}';
          _statusType = InlineStatusType.success;
        });
      case PhoneAuthSendResult.invalidPhone:
        setState(() {
          _statusMessage = PhoneAuthService.lastErrorMessage ??
              'Please enter a valid phone number.';
          _statusType = InlineStatusType.error;
        });
      case PhoneAuthSendResult.tooManyRequests:
        setState(() {
          _statusMessage = PhoneAuthService.lastErrorMessage ??
              'Too many attempts. Please try again later.';
          _statusType = InlineStatusType.info;
        });
      case PhoneAuthSendResult.networkError:
      case PhoneAuthSendResult.unknownError:
        setState(() {
          _statusMessage = PhoneAuthService.lastErrorMessage ??
              'Could not send code. Please try again.';
          _statusType = InlineStatusType.error;
        });
    }
  }

  Future<void> _verify() async {
    setState(() {
      _isVerifying = true;
      _statusMessage = null;
    });

    final ok = await PhoneAuthService.verifyCodeOnly(_codeController.text);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _statusMessage = PhoneAuthService.lastErrorMessage ??
            'Invalid code. Please try again.';
        _statusType = InlineStatusType.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Verify Phone Number',
        style: TextStyle(
          color: AppPalette.charcoal,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the code sent to ${widget.phone}',
            style: TextStyle(color: AppPalette.mutedText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Verification code',
              hintStyle: TextStyle(
                color: AppPalette.mutedText.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: AppPalette.background.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            InlineStatusMessage(
              message: _statusMessage!,
              type: _statusType,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppPalette.mutedText),
          ),
        ),
        TextButton(
          onPressed: _isSending ? null : _sendCode,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resend'),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
