import 'package:flutter/material.dart';

import '../data/trade_tools.dart';
import '../services/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/reveal.dart';
import 'tools/tool_registry.dart';

const _all = 'All';

/// Lists one trade's tools with category filters and favourites.
class TradePage extends StatefulWidget {
  const TradePage({super.key, required this.trade, required this.onBack});

  final TradeInfo trade;
  final VoidCallback onBack;

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage> with TickerProviderStateMixin {
  String _category = _all;
  bool _favouritesOnly = false;
  Set<String> _favourites = {};

  // Staggers the tool cards in; replayed whenever the filter changes.
  late final AnimationController _list = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    UserPrefs.favourites().then((ids) {
      if (mounted) setState(() => _favourites = ids);
    });
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  List<TradeTool> get _visibleTools => widget.trade.tools
      .where((t) => _category == _all || t.category == _category)
      .where((t) => !_favouritesOnly || _favourites.contains(t.id))
      .toList();

  void _setFilter({String? category, bool? favouritesOnly}) {
    setState(() {
      _category = category ?? _category;
      _favouritesOnly = favouritesOnly ?? _favouritesOnly;
    });
    _list.forward(from: 0);
  }

  void _toggleFavourite(TradeTool tool) {
    setState(() {
      if (!_favourites.remove(tool.id)) _favourites.add(tool.id);
    });
    UserPrefs.saveFavourites(_favourites);
  }

  Animation<double> _itemAnimation(int index) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    return CurvedAnimation(
      parent: _list,
      curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = _visibleTools;
    return Column(
      children: [
        PageHeader(
          title: widget.trade.name,
          subtitle:
              '${widget.trade.tools.length} tools · ${widget.trade.tagline}',
          onBack: widget.onBack,
          trailing: _MoreMenu(
            favouritesOnly: _favouritesOnly,
            onFavouritesOnly: (v) => _setFilter(favouritesOnly: v),
          ),
        ),
        const SizedBox(height: 12),
        _CategoryChips(
          categories: [_all, ...widget.trade.categories],
          selected: _category,
          onSelect: (c) => _setFilter(category: c),
        ),
        Expanded(
          child: tools.isEmpty
              ? _EmptyState(favouritesOnly: _favouritesOnly)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: tools.length,
                  itemBuilder: (_, i) => Reveal(
                    // Key by filter so replayed animations hit fresh items.
                    key: ValueKey('$_category$_favouritesOnly${tools[i].id}'),
                    animation: _itemAnimation(i),
                    child: _ToolCard(
                      tool: tools[i],
                      favourite: _favourites.contains(tools[i].id),
                      onToggleFavourite: () => _toggleFavourite(tools[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.favouritesOnly,
    required this.onFavouritesOnly,
  });

  final bool favouritesOnly;
  final ValueChanged<bool> onFavouritesOnly;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'favourites') onFavouritesOnly(!favouritesOnly);
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'favourites',
          checked: favouritesOnly,
          child: const Text('Favourites only'),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final category = categories[i];
          final active = category == selected;
          return Pressable(
            onTap: () => onSelect(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.red : AppColors.border,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? Colors.white : AppColors.muted,
                ),
                child: Text(category),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.favourite,
    required this.onToggleFavourite,
  });

  final TradeTool tool;
  final bool favourite;
  final VoidCallback onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => openTool(context, tool.id, tool.name),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          decoration: cardDecoration(),
          child: Row(
            children: [
              IconTile(tool.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleFavourite,
                tooltip: favourite ? 'Unpin' : 'Pin to favourites',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                    ),
                    child: child,
                  ),
                  child: Icon(
                    favourite ? Icons.star_rounded : Icons.star_border_rounded,
                    key: ValueKey(favourite),
                    color: favourite ? AppColors.red : AppColors.chevron,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.favouritesOnly});

  final bool favouritesOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconTile(Icons.star_border_rounded, size: 56),
            const SizedBox(height: 12),
            Text(
              favouritesOnly ? 'No favourites here yet' : 'No tools here yet',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap the star on a tool to pin it.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
