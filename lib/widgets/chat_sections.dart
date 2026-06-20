import 'package:flutter/material.dart';
import '../models/chat_summary.dart';
import 'chat_list_item.dart';

const _red = Color(0xFFF70000);
const _titleStyle = TextStyle(
  color: Colors.white,
  fontFamily: 'OptimaNova',
  fontSize: 16,
  fontWeight: FontWeight.w900,
);
const _metaStyle = TextStyle(
  color: Colors.white60,
  fontFamily: 'OptimaNova',
  fontSize: 10,
  fontWeight: FontWeight.w900,
);

class PinnedSection extends StatelessWidget {
  final List<ChatSummary> chats;
  final String? selectedChatId;
  final ValueChanged<ChatSummary> onOpenChat;

  const PinnedSection({
    super.key,
    required this.chats,
    required this.selectedChatId,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        const _SectionTitle(title: 'ON HOLD', subtitle: 'PINNED CHATS'),
        if (chats.isEmpty)
          const _EmptyPanel(
            icon: Icons.push_pin,
            title: 'NOTHING HERE',
            subtitle: 'PIN A CHAT TO KEEP IT CLOSE',
          )
        else
          for (var index = 0; index < chats.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ChatListItem(
                chat: chats[index],
                rotation: ((index * 5 + 2) % 7 - 3) * 0.008,
                isSelected: chats[index].id == selectedChatId,
                onTap: () => onOpenChat(chats[index]),
              ),
            ),
      ],
    );
  }
}

enum _SearchKind { chat, person, group, channel }

class _SearchResult {
  final String title;
  final String subtitle;
  final String initials;
  final _SearchKind kind;
  final ChatSummary? chat;

  const _SearchResult({
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.kind,
    this.chat,
  });
}

class SearchSection extends StatefulWidget {
  final List<ChatSummary> chats;
  final ValueChanged<ChatSummary> onOpenChat;

  const SearchSection({
    super.key,
    required this.chats,
    required this.onOpenChat,
  });

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _initials(ChatSummary chat) {
    final label = chat.avatarLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final title = chat.title.trim();
    return title.isEmpty ? '?' : title.substring(0, 1);
  }

  List<_SearchResult> get _allResults => [
    ...widget.chats.map(
      (chat) => _SearchResult(
        title: chat.title,
        subtitle: chat.participants.length > 1 ? 'YOUR GROUP' : 'YOUR CHAT',
        initials: _initials(chat),
        kind: _SearchKind.chat,
        chat: chat,
      ),
    ),
    const _SearchResult(
      title: 'Persona Central',
      subtitle: '128K SUBSCRIBERS',
      initials: 'PC',
      kind: _SearchKind.channel,
    ),
    const _SearchResult(
      title: 'Shujin Academy',
      subtitle: '2.4K MEMBERS',
      initials: 'SA',
      kind: _SearchKind.group,
    ),
    const _SearchResult(
      title: 'Makoto Niijima',
      subtitle: '@QUEEN',
      initials: 'MN',
      kind: _SearchKind.person,
    ),
    const _SearchResult(
      title: 'Tokyo After Dark',
      subtitle: '48K SUBSCRIBERS',
      initials: 'TD',
      kind: _SearchKind.channel,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final results = query.isEmpty
        ? _allResults
        : _allResults
              .where(
                (result) =>
                    result.title.toLowerCase().contains(query) ||
                    result.subtitle.toLowerCase().contains(query),
              )
              .toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        const _SectionTitle(title: 'FIND ANYONE', subtitle: 'GLOBAL SEARCH'),
        Transform.rotate(
          angle: -0.012,
          child: CustomPaint(
            painter: const _OutlinedPanelPainter(),
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  const Icon(Icons.search, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (_) => setState(() {}),
                      cursorColor: _red,
                      style: _titleStyle.copyWith(fontSize: 18),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'CHATS, PEOPLE, CHANNELS',
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'OptimaNova',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ResultDivider(
          label: query.isEmpty
              ? 'RECENT & DISCOVER'
              : '${results.length} FOUND',
        ),
        const SizedBox(height: 6),
        if (results.isEmpty)
          const _EmptyPanel(
            icon: Icons.search_off,
            title: 'NO RESULTS',
            subtitle: 'TRY ANOTHER NAME OR @USERNAME',
          )
        else
          for (var index = 0; index < results.length; index++)
            _SearchResultTile(
              result: results[index],
              rotation: ((index % 3) - 1) * 0.008,
              onTap: results[index].chat == null
                  ? null
                  : () => widget.onOpenChat(results[index].chat!),
            ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final double rotation;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.result,
    required this.rotation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (result.kind) {
      _SearchKind.chat => Icons.chat_bubble,
      _SearchKind.person => Icons.person,
      _SearchKind.group => Icons.group,
      _SearchKind.channel => Icons.campaign,
    };

    return Transform.rotate(
      angle: rotation,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: const _BlackPanelPainter(),
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                const SizedBox(width: 8),
                _InitialBadge(label: result.initials),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle.copyWith(fontSize: 18),
                      ),
                      Text(
                        result.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _metaStyle,
                      ),
                    ],
                  ),
                ),
                Icon(icon, color: _red, size: 24),
                const SizedBox(width: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  bool notifications = true;
  bool previews = true;
  bool animations = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      children: [
        const _SectionTitle(title: 'CONFIG', subtitle: 'MAKE IT YOURS'),
        _SettingsGroup(
          title: 'NOTIFICATIONS',
          children: [
            _SettingsToggle(
              icon: Icons.notifications,
              title: 'MESSAGES',
              subtitle: 'Alerts for new messages',
              value: notifications,
              onChanged: (value) => setState(() => notifications = value),
            ),
            _SettingsToggle(
              icon: Icons.visibility,
              title: 'PREVIEW TEXT',
              subtitle: 'Show message in notifications',
              value: previews,
              onChanged: (value) => setState(() => previews = value),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: 'APPEARANCE',
          children: [
            _SettingsToggle(
              icon: Icons.bolt,
              title: 'ANIMATIONS',
              subtitle: 'Transitions and visual effects',
              value: animations,
              onChanged: (value) => setState(() => animations = value),
            ),
            const _SettingsAction(
              icon: Icons.palette,
              title: 'ACCENT COLOR',
              value: 'PHANTOM RED',
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _SettingsGroup(
          title: 'ACCOUNT',
          children: [
            _SettingsAction(icon: Icons.lock, title: 'PRIVACY', value: 'OPEN'),
            _SettingsAction(
              icon: Icons.storage,
              title: 'DATA & STORAGE',
              value: '1.2 GB',
            ),
          ],
        ),
      ],
    );
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      children: [
        const _SectionTitle(title: 'YOUR CARD', subtitle: 'TELEGRAM PROFILE'),
        Transform.rotate(
          angle: -0.014,
          child: CustomPaint(
            painter: const _OutlinedPanelPainter(),
            child: SizedBox(
              height: 184,
              child: Stack(
                children: [
                  Positioned(
                    left: 18,
                    top: 28,
                    child: Transform.rotate(
                      angle: -0.06,
                      child: CustomPaint(
                        painter: const _AvatarFramePainter(),
                        child: SizedBox(
                          width: 100,
                          height: 112,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/portraits/yusuke.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 132,
                    right: 18,
                    top: 34,
                    child: Text(
                      'JOKER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle.copyWith(fontSize: 30),
                    ),
                  ),
                  const Positioned(
                    left: 134,
                    top: 78,
                    child: Text('@luciffio', style: _metaStyle),
                  ),
                  const Positioned(left: 134, top: 105, child: _OnlineLabel()),
                  Positioned(
                    left: 134,
                    right: 20,
                    bottom: 20,
                    child: Text(
                      'TAKE YOUR TIME',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _ProfileStat(value: '42', label: 'CHATS'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _ProfileStat(value: '8', label: 'ON HOLD'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _ProfileStat(value: '12', label: 'MEDIA'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _ProfileAction(icon: Icons.edit, label: 'EDIT PROFILE'),
        const SizedBox(height: 10),
        const _ProfileAction(icon: Icons.qr_code, label: 'MY QR CODE'),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            child: Transform.rotate(
              angle: -0.035,
              child: Text(
                title,
                style: _titleStyle.copyWith(
                  fontSize: 31,
                  height: 1,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(3, 3)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 36,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              child: Text(
                subtitle,
                style: _metaStyle.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDivider extends StatelessWidget {
  final String label;

  const _ResultDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(label, style: _metaStyle.copyWith(color: Colors.black)),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Colors.black, thickness: 4)),
      ],
    );
  }
}

class _InitialBadge extends StatelessWidget {
  final String label;

  const _InitialBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().isEmpty ? '?' : label.trim();
    return CustomPaint(
      painter: const _BadgePainter(),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Text(
            normalized
                .substring(0, normalized.length.clamp(1, 2))
                .toUpperCase(),
            style: _titleStyle.copyWith(color: Colors.black, fontSize: 17),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BlackPanelPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _metaStyle.copyWith(color: _red, fontSize: 13)),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle),
                Text(subtitle, style: _metaStyle),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: CustomPaint(
              painter: _SwitchPainter(value: value),
              child: const SizedBox(width: 48, height: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: _titleStyle)),
          Text(value, style: _metaStyle),
          const Icon(Icons.chevron_right, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}

class _OnlineLabel extends StatelessWidget {
  const _OnlineLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: _red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'ONLINE',
          style: _metaStyle.copyWith(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BlackPanelPainter(),
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: _titleStyle.copyWith(fontSize: 25, height: 1)),
            Text(label, style: _metaStyle),
          ],
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _WhitePanelPainter(),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(icon, color: Colors.black, size: 23),
            const SizedBox(width: 12),
            Text(label, style: _titleStyle.copyWith(color: Colors.black)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.black, size: 25),
            const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BlackPanelPainter(),
      child: SizedBox(
        height: 120,
        child: Row(
          children: [
            const SizedBox(width: 22),
            Icon(icon, color: Colors.white, size: 42),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle),
                  Text(subtitle, style: _metaStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Path _panelPath(Size size, {double inset = 0}) => Path()
  ..moveTo(4 + inset, 8 + inset)
  ..lineTo(size.width - inset, inset)
  ..lineTo(size.width - 8 - inset, size.height - 5 - inset)
  ..lineTo(inset, size.height - inset)
  ..close();

class _BlackPanelPainter extends CustomPainter {
  const _BlackPanelPainter();
  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(_panelPath(size), Paint()..color = Colors.black);
  @override
  bool shouldRepaint(_BlackPanelPainter oldDelegate) => false;
}

class _WhitePanelPainter extends CustomPainter {
  const _WhitePanelPainter();
  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(_panelPath(size), Paint()..color = Colors.white);
  @override
  bool shouldRepaint(_WhitePanelPainter oldDelegate) => false;
}

class _OutlinedPanelPainter extends CustomPainter {
  const _OutlinedPanelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_panelPath(size), Paint()..color = Colors.white);
    canvas.drawPath(_panelPath(size, inset: 5), Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_OutlinedPanelPainter oldDelegate) => false;
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_panelPath(size), Paint()..color = Colors.white);
    canvas.drawPath(_panelPath(size, inset: 5), Paint()..color = _red);
  }

  @override
  bool shouldRepaint(_BadgePainter oldDelegate) => false;
}

class _AvatarFramePainter extends CustomPainter {
  const _AvatarFramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_panelPath(size), Paint()..color = _red);
    canvas.drawPath(_panelPath(size, inset: 6), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AvatarFramePainter oldDelegate) => false;
}

class _SwitchPainter extends CustomPainter {
  final bool value;
  const _SwitchPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_panelPath(size), Paint()..color = Colors.white);
    canvas.drawPath(
      _panelPath(size, inset: 4),
      Paint()..color = value ? _red : Colors.black54,
    );
    canvas.drawCircle(
      Offset(value ? size.width - 13 : 13, size.height / 2),
      7,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) => oldDelegate.value != value;
}
