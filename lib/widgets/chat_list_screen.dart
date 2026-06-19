import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chat_summary.dart';
import '../services/chat_repository.dart';
import '../theme/persona_colors.dart';
import 'chat_list_item.dart';

enum _ChatSection { chats, pinned, search, settings, profile }

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
  _ChatSection _section = _ChatSection.chats;

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
                  Positioned.fill(child: _buildSection()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomNavigation(
                      selected: _section,
                      onSelected: (section) =>
                          setState(() => _section = section),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _ChatSection.chats:
        final chats = _chats;
        if (chats == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return ListView.builder(
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
        );
      case _ChatSection.pinned:
        return const _PlaceholderSection(title: 'PINNED', holdBadge: true);
      case _ChatSection.search:
        return const _PlaceholderSection(title: 'SEARCH', icon: Icons.search);
      case _ChatSection.settings:
        return const _PlaceholderSection(
          title: 'SETTINGS',
          icon: Icons.settings,
        );
      case _ChatSection.profile:
        return const _PlaceholderSection(title: 'PROFILE', icon: Icons.person);
    }
  }
}

class _BottomNavigation extends StatelessWidget {
  final _ChatSection selected;
  final ValueChanged<_ChatSection> onSelected;

  const _BottomNavigation({required this.selected, required this.onSelected});

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
            children: [
              _NavigationItem(
                icon: Icons.chat_bubble,
                tooltip: 'Chats',
                isSelected: selected == _ChatSection.chats,
                onTap: () => onSelected(_ChatSection.chats),
              ),
              const SizedBox(width: 8),
              _NavigationItem(
                icon: Icons.push_pin,
                tooltip: 'Pinned chats',
                isSelected: selected == _ChatSection.pinned,
                onTap: () => onSelected(_ChatSection.pinned),
              ),
              const SizedBox(width: 8),
              _NavigationItem(
                icon: Icons.search,
                tooltip: 'Search',
                isSelected: selected == _ChatSection.search,
                onTap: () => onSelected(_ChatSection.search),
              ),
              const SizedBox(width: 8),
              _NavigationItem(
                icon: Icons.settings,
                tooltip: 'Settings',
                isSelected: selected == _ChatSection.settings,
                onTap: () => onSelected(_ChatSection.settings),
              ),
              const SizedBox(width: 8),
              _NavigationItem(
                icon: Icons.person,
                tooltip: 'Profile',
                isSelected: selected == _ChatSection.profile,
                onTap: () => onSelected(_ChatSection.profile),
              ),
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
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 50,
            child: CustomPaint(
              painter: _NavigationItemPainter(isSelected: isSelected),
              child: Icon(
                icon,
                size: 25,
                color: isSelected ? Colors.black : Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool holdBadge;

  const _PlaceholderSection({
    required this.title,
    this.icon,
    this.holdBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 96),
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.rotate(
          angle: -0.045,
          child: CustomPaint(
            painter: const _PlaceholderPainter(),
            child: SizedBox(
              width: 260,
              height: 128,
              child: Stack(
                children: [
                  Positioned(
                    left: 22,
                    top: 48,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'OptimaNova',
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 22,
                    child: holdBadge
                        ? SvgPicture.asset(
                            'assets/icons/hold_badge.svg',
                            width: 94,
                            height: 46,
                            fit: BoxFit.contain,
                          )
                        : Icon(icon, color: Colors.white, size: 50),
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

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(8, 16)
      ..lineTo(size.width, 2)
      ..lineTo(size.width - 18, size.height)
      ..lineTo(0, size.height - 12)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_PlaceholderPainter oldDelegate) => false;
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
