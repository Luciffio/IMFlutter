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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
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
                showHoldBadge: false,
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
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

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WipPanel();
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WipPanel();
  }
}

class _WipPanel extends StatelessWidget {
  const _WipPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.055,
        child: CustomPaint(
          painter: const _WipPainter(),
          child: const SizedBox(
            width: 210,
            height: 112,
            child: Center(
              child: Text(
                'WIP',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'OptimaNova',
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
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

class _WipPainter extends CustomPainter {
  const _WipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_panelPath(size), Paint()..color = Colors.white);
    canvas.drawPath(_panelPath(size, inset: 6), Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_WipPainter oldDelegate) => false;
}
