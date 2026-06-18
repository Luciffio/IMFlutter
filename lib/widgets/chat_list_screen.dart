import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chat_summary.dart';
import '../services/chat_repository.dart';
import '../theme/persona_colors.dart';
import 'chat_list_item.dart';

class ChatListScreen extends StatefulWidget {
  final ChatRepository repository;
  final void Function(ChatSummary chat) onOpenChat;

  const ChatListScreen({
    super.key,
    required this.repository,
    required this.onOpenChat,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatSummary>? _chats;
  String? _selectedChatId;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final chats = await widget.repository.getChats();
    if (!mounted) return;
    setState(() {
      _chats = chats;
      _selectedChatId ??= chats.isEmpty ? null : chats.first.id;
    });
  }

  void _openChat(ChatSummary chat) {
    setState(() => _selectedChatId = chat.id);
    widget.onOpenChat(chat);
  }

  /// Small deterministic tilt per row so the stack looks hand-pinned.
  double _rotationFor(int index) =>
      ((index * 5 + 2) % 7 - 3) * 0.008; // ≈ ±1.4°

  @override
  Widget build(BuildContext context) {
    final chats = _chats;
    return Scaffold(
      backgroundColor: kPersonaRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: _ImLogo(),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: chats == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
                            itemCount: chats.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ChatListItem(
                                chat: chats[i],
                                rotation: _rotationFor(i),
                                isSelected: chats[i].id == _selectedChatId,
                                onTap: () => _openChat(chats[i]),
                              ),
                            ),
                          ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomNavigation(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomPaint(
      painter: const _NavigationBackgroundPainter(),
      child: SizedBox(
        height: 70 + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _NavigationItem(
                icon: Icons.chat_bubble,
                tooltip: 'Chats',
                isSelected: true,
              ),
              SizedBox(width: 18),
              _NavigationItem(icon: Icons.people_alt, tooltip: 'Contacts'),
              SizedBox(width: 18),
              _NavigationItem(icon: Icons.settings, tooltip: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;

  const _NavigationItem({
    required this.icon,
    required this.tooltip,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        selected: isSelected,
        button: true,
        child: SizedBox(
          width: 54,
          height: 50,
          child: CustomPaint(
            painter: _NavigationItemPainter(isSelected: isSelected),
            child: Icon(
              icon,
              size: 27,
              color: isSelected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationBackgroundPainter extends CustomPainter {
  const _NavigationBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 16)
      ..lineTo(size.width, 3)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_NavigationBackgroundPainter oldDelegate) => false;
}

class _NavigationItemPainter extends CustomPainter {
  final bool isSelected;

  const _NavigationItemPainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isSelected) return;
    final path = Path()
      ..moveTo(5, 5)
      ..lineTo(size.width - 3, 1)
      ..lineTo(size.width, size.height - 7)
      ..lineTo(1, size.height - 2)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_NavigationItemPainter oldDelegate) =>
      oldDelegate.isSelected != isSelected;
}

// ── "IM" logo ───────────────────────────────────────────────────────────────

class _ImLogo extends StatelessWidget {
  const _ImLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/logo_im.svg',
      width: 112,
      height: 88,
      fit: BoxFit.contain,
    );
  }
}
