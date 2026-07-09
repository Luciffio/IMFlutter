import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/chat_summary.dart';
import '../services/chat_repository.dart';
import '../theme/persona_colors.dart';
import 'background_particles.dart';
import 'chat_list_item.dart';
import 'chat_sections.dart';
import 'persona_progress.dart';

enum _ChatSection { chats, pinned, search, settings, profile }

enum _ChatListAction { toggleUnread, togglePinned, toggleArchived }

class ChatListScreen extends StatefulWidget {
  final ChatRepository repository;
  final List<int> accountSlots;
  final int activeAccountSlot;
  final PersonaParticleMode particleMode;
  final PersonaSeason particleSeason;
  final bool transitionAnimationsEnabled;
  final ValueChanged<PersonaParticleMode> onParticleModeChanged;
  final ValueChanged<bool> onTransitionAnimationsChanged;
  final void Function(ChatSummary chat) onOpenChat;
  final VoidCallback onOpenAuth;
  final Future<void> Function(int slot) onSwitchAccount;
  final Future<void> Function() onAddAccount;
  final Future<void> Function() onSignOut;

  const ChatListScreen({
    super.key,
    required this.repository,
    this.accountSlots = const [0],
    this.activeAccountSlot = 0,
    required this.particleMode,
    required this.particleSeason,
    required this.transitionAnimationsEnabled,
    required this.onParticleModeChanged,
    required this.onTransitionAnimationsChanged,
    required this.onOpenChat,
    required this.onOpenAuth,
    required this.onSwitchAccount,
    required this.onAddAccount,
    required this.onSignOut,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatSummary>? _chats;
  String? _selectedChatId;
  _ChatSection _section = _ChatSection.chats;
  late final PageController _pageController;
  StreamSubscription<List<ChatSummary>>? _chatSub;
  Timer? _archiveHoldTimer;
  int? _archivePointer;
  Offset? _archiveSwipeStart;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _chatSub = widget.repository.chats.listen(_setChats);
    _loadChats();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _archiveHoldTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final chats = await widget.repository.getChats();
    if (!mounted) return;
    _setChats(chats);
  }

  void _setChats(List<ChatSummary> chats) {
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

  Future<void> _showChatActions(ChatSummary chat) async {
    unawaited(HapticFeedback.mediumImpact());
    if (!mounted) return;
    final action = await showModalBottomSheet<_ChatListAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _ChatActionsSheet(chat: chat),
    );
    if (action == null || !mounted) return;

    try {
      switch (action) {
        case _ChatListAction.toggleUnread:
          await widget.repository.setChatMarkedUnread(
            chat.id,
            !chat.isMarkedUnread,
          );
        case _ChatListAction.togglePinned:
          await widget.repository.setChatPinned(chat.id, !chat.isPinned);
        case _ChatListAction.toggleArchived:
          await widget.repository.setChatArchived(chat.id, !chat.isArchived);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black,
          content: Text(
            error.toString().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'OptimaNova',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showAccountActions() async {
    unawaited(HapticFeedback.mediumImpact());
    if (!mounted) return;
    final action = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _AccountActionsSheet(
        accountSlots: widget.accountSlots,
        activeAccountSlot: widget.activeAccountSlot,
      ),
    );
    if (action == null || !mounted) return;
    if (action == -1) {
      await widget.onAddAccount();
    } else if (action == -2) {
      await widget.onSignOut();
    } else {
      await widget.onSwitchAccount(action);
    }
  }

  void _selectSection(_ChatSection section) {
    if (section == _section) return;
    if (!widget.transitionAnimationsEnabled) {
      _pageController.jumpToPage(section.index);
      return;
    }

    _pageController.animateToPage(
      section.index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Small deterministic tilt per row so the stack looks hand-pinned.
  double _rotationFor(int index) =>
      ((index * 5 + 2) % 7 - 3) * 0.008; // Ã¢â€°Ë† Ã‚Â±1.4Ã‚Â°

  void _onArchivePointerDown(PointerDownEvent event) {
    if (_section != _ChatSection.chats ||
        event.position.dx > 96 ||
        _archivePointer != null) {
      return;
    }
    _archivePointer = event.pointer;
    _archiveSwipeStart = event.position;
  }

  void _onArchivePointerMove(PointerMoveEvent event) {
    if (event.pointer != _archivePointer || _archiveSwipeStart == null) return;
    final delta = event.position - _archiveSwipeStart!;
    if (delta.dx < 0 || delta.dy.abs() > 48) {
      _resetArchiveGesture();
      return;
    }
    if (delta.dx >= 72 && _archiveHoldTimer == null) {
      _archiveHoldTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || _archivePointer == null) return;
        unawaited(HapticFeedback.heavyImpact());
        _resetArchiveGesture();
        _openArchive();
      });
    }
  }

  void _resetArchiveGesture() {
    _archiveHoldTimer?.cancel();
    _archiveHoldTimer = null;
    _archivePointer = null;
    _archiveSwipeStart = null;
  }

  void _openArchive() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: widget.transitionAnimationsEnabled
            ? const Duration(milliseconds: 320)
            : Duration.zero,
        reverseTransitionDuration: widget.transitionAnimationsEnabled
            ? const Duration(milliseconds: 240)
            : Duration.zero,
        pageBuilder: (_, _, _) => _ArchiveScreen(
          repository: widget.repository,
          particleSeason: widget.particleSeason,
          onOpenChat: _openChat,
          onChatLongPress: _showChatActions,
        ),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPersonaRed,
      body: Listener(
        key: const ValueKey('archive_swipe_detector'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onArchivePointerDown,
        onPointerMove: _onArchivePointerMove,
        onPointerUp: (_) => _resetArchiveGesture(),
        onPointerCancel: (_) => _resetArchiveGesture(),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackgroundParticles(season: widget.particleSeason),
              ),
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
                      child: SettingsSection(
                        particleMode: widget.particleMode,
                        transitionAnimationsEnabled:
                            widget.transitionAnimationsEnabled,
                        onParticleModeChanged: widget.onParticleModeChanged,
                        onTransitionAnimationsChanged:
                            widget.onTransitionAnimationsChanged,
                        onOpenAuth: widget.onOpenAuth,
                      ),
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
                  onProfileLongPress: _showAccountActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatsSection() {
    final chats = _chats;
    if (chats == null) {
      return const Center(child: PersonaLoadingMark(label: 'CHATS'));
    }
    final mainChats = chats.where((chat) => !chat.isArchived).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 112, 12, 92),
      itemCount: mainChats.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ChatListItem(
          chat: mainChats[i],
          rotation: _rotationFor(i),
          isSelected: mainChats[i].id == _selectedChatId,
          onTap: () => _openChat(mainChats[i]),
          onLongPress: () => _showChatActions(mainChats[i]),
        ),
      ),
    );
  }

  Widget _buildPinnedSection() {
    final chats = _chats;
    if (chats == null) {
      return const Center(child: PersonaLoadingMark(label: 'PINNED'));
    }
    return PinnedSection(
      chats: chats.where((chat) => chat.isPinned && !chat.isArchived).toList(),
      selectedChatId: _selectedChatId,
      onOpenChat: _openChat,
      onChatLongPress: _showChatActions,
      topPadding: 112,
    );
  }
}

class _ArchiveScreen extends StatefulWidget {
  final ChatRepository repository;
  final PersonaSeason particleSeason;
  final ValueChanged<ChatSummary> onOpenChat;
  final Future<void> Function(ChatSummary) onChatLongPress;

  const _ArchiveScreen({
    required this.repository,
    required this.particleSeason,
    required this.onOpenChat,
    required this.onChatLongPress,
  });

  @override
  State<_ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<_ArchiveScreen> {
  StreamSubscription<List<ChatSummary>>? _subscription;
  List<ChatSummary>? _chats;
  String? _selectedChatId;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.chats.listen(_setChats);
    unawaited(_loadChats());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    _setChats(await widget.repository.getChats());
  }

  void _setChats(List<ChatSummary> chats) {
    if (!mounted) return;
    setState(() {
      _chats = chats.where((chat) => chat.isArchived).toList();
      if (_chats!.every((chat) => chat.id != _selectedChatId)) {
        _selectedChatId = null;
      }
    });
  }

  double _rotationFor(int index) => ((index * 3 + 1) % 5 - 2) * 0.009;

  @override
  Widget build(BuildContext context) {
    final chats = _chats;
    return Scaffold(
      backgroundColor: kPersonaRed,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackgroundParticles(season: widget.particleSeason),
            ),
            if (chats == null)
              const Center(child: PersonaLoadingMark(label: 'LOADING'))
            else if (chats.isEmpty)
              const Center(
                child: Text(
                  'ARCHIVE EMPTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'OptimaNova',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black, blurRadius: 0)],
                  ),
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 108, 12, 30),
                itemCount: chats.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ChatListItem(
                    chat: chats[index],
                    rotation: _rotationFor(index),
                    isSelected: chats[index].id == _selectedChatId,
                    onTap: () {
                      setState(() => _selectedChatId = chats[index].id);
                      widget.onOpenChat(chats[index]);
                    },
                    onLongPress: () => widget.onChatLongPress(chats[index]),
                  ),
                ),
              ),
            Positioned(
              left: 18,
              top: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Transform.rotate(
                  angle: -0.05,
                  child: Container(
                    width: 48,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 4),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 78,
              top: 12,
              child: Text(
                'ARCHIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'OptimaNova',
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, offset: Offset(3, 3))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatActionsSheet extends StatelessWidget {
  final ChatSummary chat;

  const _ChatActionsSheet({required this.chat});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'OptimaNova',
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _ChatActionButton(
              icon: chat.isMarkedUnread
                  ? Icons.mark_chat_read
                  : Icons.mark_chat_unread,
              label: chat.isMarkedUnread
                  ? 'MARK AS READ'
                  : 'MARK UNREAD / HOLD',
              onTap: () => Navigator.pop(context, _ChatListAction.toggleUnread),
            ),
            const SizedBox(height: 8),
            _ChatActionButton(
              icon: chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: chat.isPinned ? 'UNPIN CHAT' : 'PIN CHAT',
              onTap: () => Navigator.pop(context, _ChatListAction.togglePinned),
            ),
            const SizedBox(height: 8),
            _ChatActionButton(
              icon: chat.isArchived ? Icons.unarchive : Icons.archive,
              label: chat.isArchived ? 'RETURN TO CHATS' : 'ARCHIVE CHAT',
              onTap: () =>
                  Navigator.pop(context, _ChatListAction.toggleArchived),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ChatActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, color: Colors.black, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'OptimaNova',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountActionsSheet extends StatelessWidget {
  final List<int> accountSlots;
  final int activeAccountSlot;

  const _AccountActionsSheet({
    required this.accountSlots,
    required this.activeAccountSlot,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ACCOUNTS',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'OptimaNova',
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final slot in accountSlots) ...[
              _ChatActionButton(
                icon: slot == activeAccountSlot
                    ? Icons.account_circle
                    : Icons.person_outline,
                label:
                    'ACCOUNT ${slot + 1}${slot == activeAccountSlot ? ' / ACTIVE' : ''}',
                onTap: () => Navigator.pop(context, slot),
              ),
              const SizedBox(height: 8),
            ],
            _ChatActionButton(
              icon: Icons.person_add,
              label: 'ADD ACCOUNT',
              onTap: () => Navigator.pop(context, -1),
            ),
            const SizedBox(height: 8),
            _ChatActionButton(
              icon: Icons.logout,
              label: 'LOG OUT',
              onTap: () => Navigator.pop(context, -2),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final _ChatSection selected;
  final ValueChanged<_ChatSection> onSelected;
  final VoidCallback onProfileLongPress;

  const _BottomNavigation({
    required this.selected,
    required this.onSelected,
    required this.onProfileLongPress,
  });

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
                onLongPress: onProfileLongPress,
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
  final VoidCallback? onLongPress;

  const _NavigationItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        label: tooltip,
        selected: isSelected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
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
