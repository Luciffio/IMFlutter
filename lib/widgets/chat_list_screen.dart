import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chat_summary.dart';
import '../services/chat_repository.dart';
import '../theme/persona_colors.dart';
import 'chat_list_item.dart';
import 'chat_sections.dart';

enum _ChatSection { chats, pinned, search, settings, profile }

class ChatListScreen extends StatefulWidget {
  final ChatRepository repository;
  final void Function(ChatSummary chat) onOpenChat;
  final VoidCallback onOpenAuth;

  const ChatListScreen({
    super.key,
    required this.repository,
    required this.onOpenChat,
    required this.onOpenAuth,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatSummary>? _chats;
  String? _selectedChatId;
  _ChatSection _section = _ChatSection.chats;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadChats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  void _selectSection(_ChatSection section) {
    if (section == _section) return;
    _pageController.animateToPage(
      section.index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Small deterministic tilt per row so the stack looks hand-pinned.
  double _rotationFor(int index) =>
      ((index * 5 + 2) % 7 - 3) * 0.008; // Ã¢â€°Ë† Ã‚Â±1.4Ã‚Â°

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPersonaRed,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _section = _ChatSection.values[index]),
                children: [
                  _buildChatsSection(),
                  _buildPinnedSection(),
                  Padding(
                    padding: const EdgeInsets.only(top: 108),
                    child: SearchSection(
                      chats: _chats ?? const [],
                      onOpenChat: _openChat,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 108),
                    child: SettingsSection(onOpenAuth: widget.onOpenAuth),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 108),
                    child: ProfileSection(),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 20,
              top: 12,
              child: IgnorePointer(child: _ImLogo()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomNavigation(
                selected: _section,
                onSelected: _selectSection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsSection() {
    final chats = _chats;
    if (chats == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 112, 12, 92),
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
  }

  Widget _buildPinnedSection() {
    final chats = _chats;
    if (chats == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return PinnedSection(
      chats: chats.where((chat) => chat.isPinned).toList(),
      selectedChatId: _selectedChatId,
      onOpenChat: _openChat,
      topPadding: 112,
    );
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

// Ã¢â€â‚¬Ã¢â€â‚¬ "IM" logo Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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
