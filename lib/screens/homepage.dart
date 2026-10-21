import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/trade_tools.dart';
import '../services/notes_repository.dart';
import '../services/notifications.dart';
import '../services/recents.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fade_route.dart';
import '../widgets/reveal.dart';
import 'notes/notes_page.dart';
import 'notifications_page.dart';
import 'tools/tool_registry.dart';
import 'trade_page.dart';

class _Tool {
  const _Tool(this.label, this.icon, [this.id = '']);
  final String label;
  final IconData icon;
  final String id;
}

class _Trade {
  const _Trade(this.name, this.icon, this.toolCount);
  final String name;
  final IconData icon;
  final int toolCount;
}

const _pinned = [
  _Tool('Unit\nConverter', Icons.swap_horiz_rounded, 'unit_converter'),
  _Tool('Cable\nSize', Icons.bolt_rounded, 'elec_cable_size'),
  _Tool('Concrete', Icons.layers_outlined),
  _Tool('Pipe\nSizing', Icons.water_drop_outlined),
];

const _quickTools = [
  _Tool('Scientific Calculator', Icons.calculate_outlined, 'sci_calculator'),
  _Tool('Material Weight', Icons.scale_outlined),
  _Tool('Area / Volume', Icons.square_foot_rounded),
  _Tool('Site Notes + Photos', Icons.photo_camera_outlined, 'site_notes'),
];

const _trades = [
  _Trade('Electrical', Icons.bolt_rounded, 16),
  _Trade('Plumbing', Icons.water_drop_outlined, 12),
  _Trade('Mechanical', Icons.settings_outlined, 14),
  _Trade('Civil', Icons.foundation_rounded, 18),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.name});

  final String name;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Recents.load();
    Notifications.load().then((_) => _logReminders());
    // Note reminders that come due while the app is open.
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _logReminders(),
    );

    final reminders = ReminderService.instance;
    reminders.tappedNoteId.addListener(_onReminderTapped);
    final launchId = reminders.launchNoteId;
    if (launchId != null) {
      reminders.launchNoteId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNote(launchId));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    ReminderService.instance.tappedNoteId.removeListener(_onReminderTapped);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _logReminders();
  }

  Future<void> _logReminders() async {
    if (!NotesRepository.instance.isReady) return;
    try {
      await NotesRepository.instance.logDueReminders();
    } catch (e) {
      debugPrint('Logging reminders failed: $e');
    }
  }

  void _onReminderTapped() {
    final id = ReminderService.instance.tappedNoteId.value;
    if (id == null) return;
    ReminderService.instance.tappedNoteId.value = null;
    _openNote(id);
  }

  void _openNote(String id) {
    final note = NotesRepository.instance.byId(id);
    if (note == null || !mounted) return;
    _logReminders();
    openNote(context, note);
  }

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.bolt_rounded, label: 'Elec'),
    (icon: Icons.water_drop_outlined, label: 'Plumb'),
    (icon: Icons.settings_outlined, label: 'Mech'),
    (icon: Icons.foundation_rounded, label: 'Civil'),
  ];

  void _openTab(int tab) => setState(() => _tab = tab);

  Widget _body() {
    return switch (_tab) {
      0 => _HomeTab(
        key: const ValueKey('home'),
        name: widget.name,
        onOpenTrade: (i) => _openTab(i + 1),
      ),
      1 => TradePage(
        key: const ValueKey('electrical'),
        trade: electrical,
        onBack: () => _openTab(0),
      ),
      _ => _TradeTab(key: ValueKey(_tab), trade: _trades[_tab - 1]),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _tab == 0 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      // System back on a trade tab returns home instead of leaving the app.
      child: PopScope(
        canPop: _tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _openTab(0);
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _body(),
          ),
          bottomNavigationBar: _BottomNav(
            items: _tabs,
            current: _tab,
            onSelect: _openTab,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home tab
// ---------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key, required this.name, required this.onOpenTrade});

  final String name;
  final ValueChanged<int> onOpenTrade;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(name: widget.name)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.list(
              children: [
                const _SectionTitle('Pinned'),
                const _PinnedRow(),
                const _SectionTitle('Quick tools'),
                const _QuickTools(),
                const _SectionTitle('Trades'),
                _TradeGrid(onOpen: widget.onOpenTrade),
                const _SectionTitle('Recent calculations'),
                const _RecentCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Bottom margin leaves room for the overlapping search bar.
        Container(
          margin: const EdgeInsets.only(bottom: 26),
          padding: EdgeInsets.fromLTRB(20, top + 10, 8, 48),
          decoration: const BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Image.asset(
                        AppAssets.appIcon,
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SiteKit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const _BellButton(),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '$_greeting, ${name.split(' ').first}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const SiteChip(),
            ],
          ),
        ),
        const Positioned(left: 20, right: 20, bottom: 0, child: _SearchBar()),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Notifications.items,
      builder: (context, _, _) => IconButton(
        tooltip: 'Notifications',
        onPressed: () =>
            Navigator.of(context).push(fadeRoute(const NotificationsPage())),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 26,
            ),
            if (Notifications.unread > 0)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.red, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.muted, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              cursorColor: AppColors.red,
              style: TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search tools',
                hintStyle: TextStyle(color: AppColors.faint, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 0, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, tool) in _pinned.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Pressable(
              onTap: () => openTool(context, tool.id, tool.label),
              child: Container(
                height: 96,
                decoration: cardDecoration(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tool.icon, color: AppColors.red, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      tool.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickTools extends StatelessWidget {
  const _QuickTools();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          for (final (i, tool) in _quickTools.indexed) ...[
            if (i > 0)
              const Divider(height: 1, indent: 52, color: AppColors.border),
            InkWell(
              onTap: () => openTool(context, tool.id, tool.label),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(tool.icon, size: 22, color: AppColors.red),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tool.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.chevron,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TradeGrid extends StatelessWidget {
  const _TradeGrid({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        for (final (i, trade) in _trades.indexed)
          Pressable(
            onTap: () => onOpen(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  IconTile(trade.icon, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trade.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${trade.toolCount} tools',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RecentCalc>>(
      valueListenable: Recents.items,
      builder: (context, recents, _) => Container(
        decoration: cardDecoration(),
        child: recents.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconTile(Icons.history_rounded, size: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No calculations yet. Saved results will show here.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  for (final (i, recent) in recents.take(5).indexed) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.border,
                      ),
                    InkWell(
                      onTap: () =>
                          openTool(context, recent.toolId, recent.tool),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                // Newest entry gets full brand red, older fade.
                                color: AppColors.red.withValues(
                                  alpha: (1.0 - i * 0.2).clamp(0.2, 1.0),
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: recent.tool,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          '  ${recent.result} · ${recent.site}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              recent.ago,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trade tabs (placeholder until each trade's tools are built)
// ---------------------------------------------------------------------------

class _TradeTab extends StatelessWidget {
  const _TradeTab({super.key, required this.trade});

  final _Trade trade;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(trade.icon, size: 72),
            const SizedBox(height: 16),
            Text(
              trade.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${trade.toolCount} tools coming soon',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.current,
    required this.onSelect,
  });

  final List<({IconData icon, String label})> items;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(i);
                    },
                    child: _NavItem(
                      icon: item.icon,
                      label: item.label,
                      selected: i == current,
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 250);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: selected ? 52 : 40,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? AppColors.redTint : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? AppColors.red : const Color(0xFF9A9AA0),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: duration,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            letterSpacing: 0.4,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.red : const Color(0xFF9A9AA0),
          ),
          child: Text(label.toUpperCase()),
        ),
      ],
    );
  }
}
