import 'package:flutter/material.dart';
import '../models/chat_summary.dart';
import 'background_particles.dart';
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
  final ValueChanged<ChatSummary>? onChatLongPress;
  final double topPadding;

  const PinnedSection({
    super.key,
    required this.chats,
    required this.selectedChatId,
    required this.onOpenChat,
    this.onChatLongPress,
    this.topPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, 96),
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
                onLongPress: onChatLongPress == null
                    ? null
                    : () => onChatLongPress!(chats[index]),
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
        subtitle: _chatSubtitle(chat),
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

  String _chatSubtitle(ChatSummary chat) {
    return switch (chat.type) {
      ChatType.direct => 'YOUR CHAT',
      ChatType.group => 'YOUR GROUP',
      ChatType.channel => 'YOUR CHANNEL',
    };
  }

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
  final PersonaParticleMode particleMode;
  final bool transitionAnimationsEnabled;
  final ValueChanged<PersonaParticleMode> onParticleModeChanged;
  final ValueChanged<bool> onTransitionAnimationsChanged;
  final VoidCallback onOpenAuth;

  const SettingsSection({
    super.key,
    required this.particleMode,
    required this.transitionAnimationsEnabled,
    required this.onParticleModeChanged,
    required this.onTransitionAnimationsChanged,
    required this.onOpenAuth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _WipPanel(),
          const SizedBox(height: 22),
          _SeasonModeControl(
            mode: particleMode,
            onChanged: onParticleModeChanged,
          ),
          const SizedBox(height: 18),
          _TransitionToggle(
            enabled: transitionAnimationsEnabled,
            onChanged: onTransitionAnimationsChanged,
          ),
          const SizedBox(height: 22),
          Transform.rotate(
            angle: 0.025,
            child: CustomPaint(
              painter: const _SettingsActionPainter(),
              child: InkWell(
                onTap: onOpenAuth,
                child: const SizedBox(
                  width: 230,
                  height: 58,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login, color: Colors.black, size: 25),
                      SizedBox(width: 10),
                      Text(
                        'AUTH SCREEN',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'OptimaNova',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransitionToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _TransitionToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.01,
      child: CustomPaint(
        painter: const _BlackPanelPainter(),
        child: InkWell(
          onTap: () => onChanged(!enabled),
          child: SizedBox(
            width: 310,
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Checkbox(
                  value: enabled,
                  onChanged: (value) => onChanged(value ?? false),
                  checkColor: Colors.white,
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return _red;
                    return Colors.white;
                  }),
                  side: const BorderSide(color: Colors.white, width: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TRANSITIONS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle.copyWith(fontSize: 20),
                  ),
                ),
                Text(
                  enabled ? 'ON' : 'OFF',
                  style: _metaStyle.copyWith(
                    color: enabled ? _red : Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonModeControl extends StatelessWidget {
  static const _modes = [
    PersonaParticleMode.auto,
    PersonaParticleMode.spring,
    PersonaParticleMode.summer,
    PersonaParticleMode.winter,
    PersonaParticleMode.none,
  ];

  final PersonaParticleMode mode;
  final ValueChanged<PersonaParticleMode> onChanged;

  const _SeasonModeControl({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final index = _modes.indexOf(mode).clamp(0, _modes.length - 1);

    return Transform.rotate(
      angle: -0.012,
      child: CustomPaint(
        painter: const _BlackPanelPainter(),
        child: SizedBox(
          width: 310,
          height: 124,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.ac_unit, color: _red, size: 20),
                    const SizedBox(width: 8),
                    Text('SEASON', style: _titleStyle.copyWith(fontSize: 20)),
                    const Spacer(),
                    Text(
                      _modeLabel(mode),
                      style: _metaStyle.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _red,
                    inactiveTrackColor: Colors.white,
                    thumbColor: Colors.white,
                    overlayColor: _red.withValues(alpha: 0.18),
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 2.8,
                    ),
                    activeTickMarkColor: Colors.black,
                    inactiveTickMarkColor: Colors.black,
                  ),
                  child: Slider(
                    min: 0,
                    max: (_modes.length - 1).toDouble(),
                    divisions: _modes.length - 1,
                    value: index.toDouble(),
                    onChanged: (value) {
                      final nextIndex = value.round().clamp(
                        0,
                        _modes.length - 1,
                      );
                      onChanged(_modes[nextIndex]);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final entry in _modes.indexed)
                      Text(
                        _shortModeLabel(entry.$2),
                        style: _metaStyle.copyWith(
                          color: entry.$1 == index ? _red : Colors.white70,
                        ),
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

  String _modeLabel(PersonaParticleMode mode) {
    return switch (mode) {
      PersonaParticleMode.auto => 'DYNAMIC',
      PersonaParticleMode.spring => 'SPRING',
      PersonaParticleMode.summer => 'SUMMER',
      PersonaParticleMode.winter => 'WINTER',
      PersonaParticleMode.none => 'NONE',
    };
  }

  String _shortModeLabel(PersonaParticleMode mode) {
    return switch (mode) {
      PersonaParticleMode.auto => 'DYN',
      PersonaParticleMode.spring => 'SPR',
      PersonaParticleMode.summer => 'SUM',
      PersonaParticleMode.winter => 'WIN',
      PersonaParticleMode.none => 'OFF',
    };
  }
}

class _SettingsActionPainter extends CustomPainter {
  const _SettingsActionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Path()
      ..moveTo(3, 8)
      ..lineTo(size.width - 5, 0)
      ..lineTo(size.width, size.height - 7)
      ..lineTo(9, size.height)
      ..close();
    canvas.drawPath(shadow, Paint()..color = Colors.black);

    final face = Path()
      ..moveTo(0, 3)
      ..lineTo(size.width - 10, 5)
      ..lineTo(size.width - 5, size.height - 12)
      ..lineTo(5, size.height - 5)
      ..close();
    canvas.drawPath(face, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SettingsActionPainter oldDelegate) => false;
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
