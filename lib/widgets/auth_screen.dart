import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _AuthStep { phone, code, password }

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onCancel;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    required this.onCancel,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _controller = TextEditingController();
  _AuthStep _step = _AuthStep.phone;
  int _direction = 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_controller.text.trim().isEmpty) return;
    switch (_step) {
      case _AuthStep.phone:
        _moveTo(_AuthStep.code);
      case _AuthStep.code:
        _moveTo(_AuthStep.password);
      case _AuthStep.password:
        widget.onAuthenticated();
    }
  }

  void _moveTo(_AuthStep step) {
    setState(() {
      _direction = step.index > _step.index ? 1 : -1;
      _step = step;
      _controller.clear();
    });
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
                    controller: _controller,
                    onContinue: _continue,
                    onBack: _step == _AuthStep.phone
                        ? widget.onCancel
                        : () => _moveTo(_AuthStep.values[_step.index - 1]),
                    onSkipPassword: _step == _AuthStep.password
                        ? widget.onAuthenticated
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
  final _AuthStep step;
  final TextEditingController controller;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkipPassword;

  const _AuthPanel({
    super.key,
    required this.step,
    required this.controller,
    required this.onContinue,
    required this.onBack,
    required this.onSkipPassword,
  });

  String get _title => switch (step) {
    _AuthStep.phone => 'YOUR NUMBER',
    _AuthStep.code => 'THE CODE',
    _AuthStep.password => '2FA PASSWORD',
  };

  String get _hint => switch (step) {
    _AuthStep.phone => '+1 555 000 0000',
    _AuthStep.code => '00000',
    _AuthStep.password => 'Password',
  };

  String get _caption => switch (step) {
    _AuthStep.phone => 'CONNECT YOUR TELEGRAM ACCOUNT',
    _AuthStep.code => 'ENTER THE CODE FROM TELEGRAM',
    _AuthStep.password => 'ONLY IF TWO-STEP VERIFICATION IS ON',
  };

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
                      obscureText: step == _AuthStep.password,
                      keyboardType: step == _AuthStep.password
                          ? TextInputType.visiblePassword
                          : TextInputType.phone,
                      inputFormatters: step == _AuthStep.code
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      onSubmitted: (_) => onContinue(),
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
                const Spacer(),
                Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    if (onSkipPassword != null)
                      TextButton(
                        onPressed: onSkipPassword,
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
  final VoidCallback onTap;

  const _ContinueButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _ContinueButtonPainter(),
        child: const SizedBox(
          width: 126,
          height: 46,
          child: Row(
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
