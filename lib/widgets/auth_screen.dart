import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      AuthStage.waitCode => AuthStage.waitCode,
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
      case AuthStage.waitCode:
        await widget.repository.submitCode(_controller.text);
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
      case AuthStage.waitCode:
        await widget.repository.cancelAuthentication();
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

  void _setAuthState(AuthSessionState state) {
    if (!mounted) return;
    if (state.isReady) {
      widget.onAuthenticated();
      return;
    }

    final nextStep = switch (state.stage) {
      AuthStage.waitCode => AuthStage.waitCode,
      AuthStage.waitPassword => AuthStage.waitPassword,
      _ => AuthStage.waitPhone,
    };

    setState(() {
      _direction = _stepIndex(nextStep) >= _stepIndex(_step) ? 1 : -1;
      _authState = state;
      _controller.clear();
    });
  }

  int _stepIndex(AuthStage step) {
    return switch (step) {
      AuthStage.waitPhone => 0,
      AuthStage.waitCode => 1,
      AuthStage.waitPassword => 2,
      AuthStage.signedOut => 0,
      AuthStage.ready => 3,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC41001),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 20,
              child: SvgPicture.asset(
                'assets/icons/logo_im.svg',
                width: 126,
                height: 98,
              ),
            ),
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
  final Future<void> Function()? onSkipPassword;

  const _AuthPanel({
    super.key,
    required this.step,
    required this.state,
    required this.controller,
    required this.onContinue,
    required this.onBack,
    required this.onSkipPassword,
  });

  String get _title => switch (step) {
    AuthStage.waitPhone => 'YOUR NUMBER',
    AuthStage.waitCode => 'THE CODE',
    AuthStage.waitPassword => '2FA PASSWORD',
    AuthStage.signedOut => 'YOUR NUMBER',
    AuthStage.ready => 'CONNECTED',
  };

  String get _hint => switch (step) {
    AuthStage.waitPhone => '+COUNTRY CODE NUMBER',
    AuthStage.waitCode => 'LOGIN CODE',
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
    return switch (step) {
      AuthStage.waitPhone => 'CONNECT YOUR TELEGRAM ACCOUNT',
      AuthStage.waitCode => 'ENTER THE CODE FROM TELEGRAM',
      AuthStage.waitPassword => 'ONLY IF TWO-STEP VERIFICATION IS ON',
      AuthStage.signedOut => 'CONNECT YOUR TELEGRAM ACCOUNT',
      AuthStage.ready => 'SESSION READY',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.018,
      child: CustomPaint(
        painter: const _AuthPanelPainter(),
        child: SizedBox(
          height: 270,
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
                      autofocus: true,
                      obscureText: step == AuthStage.waitPassword,
                      keyboardType: step == AuthStage.waitPassword
                          ? TextInputType.visiblePassword
                          : TextInputType.phone,
                      inputFormatters: step == AuthStage.waitCode
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      onSubmitted: (_) => unawaited(onContinue()),
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
                        onPressed: () => unawaited(onBack!()),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    if (onSkipPassword != null)
                      TextButton(
                        onPressed: () => unawaited(onSkipPassword!()),
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            color: Colors.white60,
                            fontFamily: 'OptimaNova',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    const Spacer(),
                    _ContinueButton(onTap: onContinue),
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

  const _ContinueButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => unawaited(onTap()),
      child: CustomPaint(
        painter: const _ContinueButtonPainter(),
        child: SizedBox(
          width: 126,
          height: 46,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CONTINUE',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'OptimaNova',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.arrow_forward, color: Colors.black, size: 20),
            ],
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
