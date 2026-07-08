import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_session.dart';
import '../services/chat_repository.dart';

class AuthScreen extends StatefulWidget {
  final ChatRepository repository;
  final VoidCallback onAuthenticated;
  final VoidCallback onCancel;

  const AuthScreen({
    super.key,
    required this.repository,
    required this.onAuthenticated,
    required this.onCancel,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _controller = TextEditingController();
  StreamSubscription<AuthSessionState>? _authSub;
  AuthSessionState _authState = const AuthSessionState.waitPhone();
  int _direction = 1;

  AuthStage get _step {
    return switch (_authState.stage) {
      AuthStage.waitEmailAddress => AuthStage.waitEmailAddress,
      AuthStage.waitEmailCode => AuthStage.waitEmailCode,
      AuthStage.waitCode => AuthStage.waitCode,
      AuthStage.waitOtherDevice => AuthStage.waitOtherDevice,
      AuthStage.waitRegistration => AuthStage.waitRegistration,
      AuthStage.waitPassword => AuthStage.waitPassword,
      _ => AuthStage.waitPhone,
    };
  }

  @override
  void initState() {
    super.initState();
    _authSub = widget.repository.authState.listen(_setAuthState);
    unawaited(_startAuth());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startAuth() async {
    await widget.repository.startAuthentication();
    final state = await widget.repository.getAuthState();
    if (mounted) _setAuthState(state);
  }

  Future<void> _continue() async {
    if (_controller.text.trim().isEmpty) return;
    switch (_step) {
      case AuthStage.waitPhone:
        await widget.repository.submitPhoneNumber(_controller.text);
      case AuthStage.waitEmailAddress:
        await widget.repository.submitEmailAddress(_controller.text);
      case AuthStage.waitEmailCode:
        await widget.repository.submitEmailCode(_controller.text);
      case AuthStage.waitCode:
        await widget.repository.submitCode(_controller.text);
      case AuthStage.waitOtherDevice:
        final link = _authState.otherDeviceLink;
        if (link != null && link.isNotEmpty) {
          var opened = false;
          try {
            opened = await launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {
            opened = false;
          }
          if (!opened) {
            await Clipboard.setData(ClipboardData(text: link));
          }
        }
      case AuthStage.waitRegistration:
        final parts = _controller.text.trim().split(RegExp(r'\s+'));
        final firstName = parts.first;
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        await widget.repository.submitRegistration(firstName, lastName);
      case AuthStage.waitPassword:
        await widget.repository.submitPassword(_controller.text);
      case AuthStage.signedOut:
      case AuthStage.ready:
        break;
    }
  }

  Future<void> _back() async {
    switch (_step) {
      case AuthStage.waitPhone:
        await widget.repository.cancelAuthentication();
        widget.onCancel();
      case AuthStage.waitEmailAddress:
      case AuthStage.waitEmailCode:
      case AuthStage.waitCode:
      case AuthStage.waitOtherDevice:
      case AuthStage.waitRegistration:
      case AuthStage.waitPassword:
        await widget.repository.cancelAuthentication();
      case AuthStage.signedOut:
      case AuthStage.ready:
        widget.onCancel();
    }
  }

  Future<void> _skipPassword() async {
    await widget.repository.submitPassword('');
  }

  Future<void> _resendCode() async {
    await widget.repository.resendAuthenticationCode();
  }

  Future<void> _requestTelegramLogin() async {
    await widget.repository.requestQrCodeAuthentication();
  }

  void _setAuthState(AuthSessionState state) {
    if (!mounted) return;
    if (state.isReady) {
      widget.onAuthenticated();
      return;
    }

    final currentStep = _step;
    final nextStep = switch (state.stage) {
      AuthStage.waitEmailAddress => AuthStage.waitEmailAddress,
      AuthStage.waitEmailCode => AuthStage.waitEmailCode,
      AuthStage.waitCode => AuthStage.waitCode,
      AuthStage.waitOtherDevice => AuthStage.waitOtherDevice,
      AuthStage.waitRegistration => AuthStage.waitRegistration,
      AuthStage.waitPassword => AuthStage.waitPassword,
      _ => AuthStage.waitPhone,
    };
    final stepChanged = currentStep != nextStep;

    setState(() {
      _direction = _stepIndex(nextStep) >= _stepIndex(currentStep) ? 1 : -1;
      _authState = state;
      if (stepChanged) {
        _controller.text = nextStep == AuthStage.waitOtherDevice
            ? state.otherDeviceLink ?? ''
            : '';
      }
    });
  }

  int _stepIndex(AuthStage step) {
    return switch (step) {
      AuthStage.waitPhone => 0,
      AuthStage.waitEmailAddress => 1,
      AuthStage.waitEmailCode => 2,
      AuthStage.waitCode => 3,
      AuthStage.waitOtherDevice => 3,
      AuthStage.waitRegistration => 4,
      AuthStage.waitPassword => 4,
      AuthStage.signedOut => 0,
      AuthStage.ready => 5,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC41001),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 120, 22, 30),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final offset =
                        Tween<Offset>(
                          begin: Offset(_direction.toDouble(), 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: _AuthPanel(
                    key: ValueKey(_step),
                    step: _step,
                    state: _authState,
                    controller: _controller,
                    onContinue: _continue,
                    onBack: _back,
                    onResend: _authState.canResendCode ? _resendCode : null,
                    onTelegramLogin:
                        _step == AuthStage.waitPhone ||
                            _step == AuthStage.waitCode
                        ? _requestTelegramLogin
                        : null,
                    onSkipPassword: _step == AuthStage.waitPassword
                        ? _skipPassword
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final AuthStage step;
  final AuthSessionState state;
  final TextEditingController controller;
  final Future<void> Function() onContinue;
  final Future<void> Function()? onBack;
  final Future<void> Function()? onResend;
  final Future<void> Function()? onTelegramLogin;
  final Future<void> Function()? onSkipPassword;

  const _AuthPanel({
    super.key,
    required this.step,
    required this.state,
    required this.controller,
    required this.onContinue,
    required this.onBack,
    required this.onResend,
    required this.onTelegramLogin,
    required this.onSkipPassword,
  });

  String get _title => switch (step) {
    AuthStage.waitPhone => 'YOUR NUMBER',
    AuthStage.waitEmailAddress => 'YOUR EMAIL',
    AuthStage.waitEmailCode => 'EMAIL CODE',
    AuthStage.waitCode => 'THE CODE',
    AuthStage.waitOtherDevice => 'CONFIRM LOGIN',
    AuthStage.waitRegistration => 'YOUR NAME',
    AuthStage.waitPassword => '2FA PASSWORD',
    AuthStage.signedOut => 'YOUR NUMBER',
    AuthStage.ready => 'CONNECTED',
  };

  String get _hint => switch (step) {
    AuthStage.waitPhone => '+COUNTRY CODE NUMBER',
    AuthStage.waitEmailAddress => 'EMAIL ADDRESS',
    AuthStage.waitEmailCode => 'EMAIL CODE',
    AuthStage.waitCode => 'LOGIN CODE',
    AuthStage.waitOtherDevice => 'TELEGRAM LOGIN LINK',
    AuthStage.waitRegistration => 'FIRST NAME LAST NAME',
    AuthStage.waitPassword => '2FA PASSWORD',
    AuthStage.signedOut => '+COUNTRY CODE NUMBER',
    AuthStage.ready => '',
  };

  String get _caption {
    if (step == AuthStage.waitCode) {
      final delivery = state.codeDeliveryMessage ?? 'ENTER THE CODE';
      final phone = state.phoneNumber?.trim();
      if (phone != null && phone.isNotEmpty) {
        return '$delivery\n$phone';
      }
      return delivery;
    }
    if (step == AuthStage.waitEmailCode) {
      return state.codeDeliveryMessage ?? 'ENTER THE CODE FROM EMAIL';
    }
    return switch (step) {
      AuthStage.waitPhone => 'CONNECT YOUR TELEGRAM ACCOUNT',
      AuthStage.waitEmailAddress => 'TELEGRAM REQUIRES AN EMAIL ADDRESS',
      AuthStage.waitEmailCode => 'ENTER THE CODE FROM EMAIL',
      AuthStage.waitCode => 'ENTER THE CODE FROM TELEGRAM',
      AuthStage.waitOtherDevice =>
        'COPY THE LINK AND OPEN IT ON A LOGGED-IN DEVICE',
      AuthStage.waitRegistration =>
        'CONTINUING ACCEPTS THE TELEGRAM TERMS OF SERVICE',
      AuthStage.waitPassword => 'ONLY IF TWO-STEP VERIFICATION IS ON',
      AuthStage.signedOut => 'CONNECT YOUR TELEGRAM ACCOUNT',
      AuthStage.ready => 'SESSION READY',
    };
  }

  String get _continueLabel => switch (step) {
    AuthStage.waitOtherDevice => 'OPEN TG',
    AuthStage.waitRegistration => 'ACCEPT',
    _ => 'CONTINUE',
  };

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.018,
      child: CustomPaint(
        painter: const _AuthPanelPainter(),
        child: SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'OptimaNova',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'OptimaNova',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                CustomPaint(
                  painter: const _AuthFieldPainter(),
                  child: SizedBox(
                    height: 58,
                    child: TextField(
                      controller: controller,
                      enabled: !state.isLoading,
                      autofocus: step != AuthStage.waitOtherDevice,
                      readOnly: step == AuthStage.waitOtherDevice,
                      obscureText: step == AuthStage.waitPassword,
                      keyboardType: switch (step) {
                        AuthStage.waitEmailAddress =>
                          TextInputType.emailAddress,
                        AuthStage.waitCode when !state.codeIsNumeric =>
                          TextInputType.text,
                        AuthStage.waitPassword => TextInputType.visiblePassword,
                        AuthStage.waitRegistration => TextInputType.name,
                        AuthStage.waitOtherDevice => TextInputType.url,
                        _ => TextInputType.phone,
                      },
                      inputFormatters:
                          (step == AuthStage.waitCode && state.codeIsNumeric) ||
                              step == AuthStage.waitEmailCode
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      onSubmitted: state.isLoading
                          ? null
                          : (_) => unawaited(onContinue()),
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'OptimaNova',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 17,
                        ),
                        hintText: _hint,
                        hintStyle: const TextStyle(color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFF70000),
                        fontFamily: 'OptimaNova',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 44,
                        ),
                        onPressed: state.isLoading
                            ? null
                            : () => unawaited(onBack!()),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    if (onSkipPassword != null)
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => unawaited(onSkipPassword!()),
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            color: Colors.white60,
                            fontFamily: 'OptimaNova',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    if (onResend != null)
                      IconButton(
                        tooltip: 'Resend code',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 44,
                        ),
                        onPressed: state.isLoading
                            ? null
                            : () => unawaited(onResend!()),
                        icon: const Icon(Icons.refresh, color: Colors.white60),
                      ),
                    if (onTelegramLogin != null)
                      IconButton(
                        tooltip: 'Login with Telegram',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 44,
                        ),
                        onPressed: state.isLoading
                            ? null
                            : () => unawaited(onTelegramLogin!()),
                        icon: const Icon(
                          Icons.qr_code_2,
                          color: Colors.white60,
                        ),
                      ),
                    const Spacer(),
                    _ContinueButton(
                      onTap: onContinue,
                      enabled: !state.isLoading,
                      label: _continueLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final bool enabled;
  final String label;

  const _ContinueButton({
    required this.onTap,
    required this.enabled,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 120),
        child: GestureDetector(
          onTap: () => unawaited(onTap()),
          child: CustomPaint(
            painter: const _ContinueButtonPainter(),
            child: SizedBox(
              width: 160,
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'OptimaNova',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    label == 'OPEN TG'
                        ? Icons.open_in_new
                        : Icons.arrow_forward,
                    color: Colors.black,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPanelPainter extends CustomPainter {
  const _AuthPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(8, 18)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 18, size.height - 5)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(outer, Paint()..color = Colors.white);

    final inner = Path()
      ..moveTo(14, 22)
      ..lineTo(size.width - 7, 7)
      ..lineTo(size.width - 23, size.height - 12)
      ..lineTo(7, size.height - 6)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_AuthPanelPainter oldDelegate) => false;
}

class _AuthFieldPainter extends CustomPainter {
  const _AuthFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 5)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 6, size.height - 4)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AuthFieldPainter oldDelegate) => false;
}

class _ContinueButtonPainter extends CustomPainter {
  const _ContinueButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(5, 4)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 7, size.height - 4)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ContinueButtonPainter oldDelegate) => false;
}
