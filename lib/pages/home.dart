import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasViewSize = ref.watch(
      viewSizeProvider.select((size) => !size.isEmpty),
    );
    if (!hasViewSize) {
      return const SizedBox.shrink();
    }
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        child: Material(
          color: context.colorScheme.surface,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(navigationStateProvider);
              final isMobile = state.viewMode == ViewMode.mobile;
              final navigationItems = state.navigationItems;
              final currentIndex = state.currentIndex;
              final appearance =
                  Theme.of(context).extension<AppearanceTheme>() ??
                  const AppearanceTheme();
              final isAndroidAppearance = appearance.isAndroid;
              final isFloating =
                  isAndroidAppearance &&
                  appearance.floatingBottomBar &&
                  isMobile;
              final liquidGlass =
                  isAndroidAppearance && isFloating && appearance.liquidGlass;
              final isTranslucent =
                  isAndroidAppearance && (appearance.blur || isFloating);
              final navigationBarTheme = appearance.isMiuix
                  ? _NavigationBarDefaultsMiuix(
                      context,
                      transparent: isTranslucent,
                    )
                  : _NavigationBarDefaultsM3(
                      context,
                      transparent: isTranslucent,
                    );
              final bottomNavigationBar = NavigationBarTheme(
                data: navigationBarTheme,
                child: NavigationBar(
                  destinations: navigationItems
                      .map(
                        (e) => NavigationDestination(
                          icon: e.icon,
                          label: Intl.message(e.label.name),
                        ),
                      )
                      .toList(),
                  onDestinationSelected: (index) {
                    _handleToPage(navigationItems[index].label);
                  },
                  selectedIndex: currentIndex,
                ),
              );
              final navigationSurface = isTranslucent
                  ? AndroidGlassSurface(
                      blur: appearance.blur,
                      liquidGlass: liquidGlass,
                      borderRadius: isFloating
                          ? AndroidAppearanceTokens.floatingBarBorderRadius
                          : BorderRadius.zero,
                      child: bottomNavigationBar,
                    )
                  : bottomNavigationBar;
              final effectiveBottomNavigationBar = isFloating
                  ? Padding(
                      padding: AndroidAppearanceTokens.floatingBarMargin,
                      child: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        shadowColor: context.colorScheme.shadow.withValues(
                          alpha: 0.24,
                        ),
                        shape: const RoundedSuperellipseBorder(
                          borderRadius:
                              AndroidAppearanceTokens.floatingBarBorderRadius,
                        ),
                        child: navigationSurface,
                      ),
                    )
                  : navigationSurface;
              final page = child!;
              final content = FocusTraversalGroup(
                policy: PageTraversalPolicy(),
                child: MediaQuery.removePadding(
                  removeTop: false,
                  removeBottom: isMobile,
                  removeLeft: isMobile,
                  removeRight: isMobile,
                  context: context,
                  child: page,
                ),
              );
              if (isFloating) {
                final mediaQuery = MediaQuery.of(context);
                final navigationBarHeight = appearance.isMiuix
                    ? AndroidAppearanceTokens.miuixNavigationBarHeight
                    : AndroidAppearanceTokens.materialNavigationBarHeight;
                final contentBottomPadding =
                    mediaQuery.viewPadding.bottom +
                    navigationBarHeight +
                    AndroidAppearanceTokens.floatingBarMargin.vertical;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    FocusTraversalGroup(
                      policy: PageTraversalPolicy(),
                      child: MediaQuery(
                        data: mediaQuery.copyWith(
                          padding: mediaQuery.padding.copyWith(
                            left: 0,
                            right: 0,
                            bottom: contentBottomPadding,
                          ),
                        ),
                        child: page,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedVisibility.bottomNavigation(
                        visible: true,
                        child: SafeArea(
                          top: false,
                          child: MediaQuery.removePadding(
                            removeTop: true,
                            removeBottom: true,
                            removeLeft: true,
                            removeRight: true,
                            context: context,
                            child: effectiveBottomNavigationBar,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Flexible(flex: 1, child: content),
                  AnimatedVisibility.bottomNavigation(
                    visible: isMobile,
                    child: MediaQuery.removePadding(
                      removeTop: true,
                      removeBottom: false,
                      removeLeft: true,
                      removeRight: true,
                      context: context,
                      child: effectiveBottomNavigationBar,
                    ),
                  ),
                ],
              );
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final scopedView = PageFocusScope(child: navigationView);
                    final view = KeepScope(
                      key: ValueKey(navigationItem.label),
                      keep: navigationItem.keep,
                      child: isMobile
                          ? scopedView
                          : Navigator(
                              key: ValueKey(
                                '${navigationItem.label.name}_navigator',
                              ),
                              pages: [MaterialPage(child: scopedView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return Consumer(
                      key: ValueKey(navigationItem.label),
                      builder: (_, ref, child) {
                        final isActive = ref.watch(
                          currentPageLabelProvider.select(
                            (label) => label == navigationItem.label,
                          ),
                        );
                        return PageActivityScope(
                          isActive: isActive,
                          child: ExcludeFocus(
                            excluding: !isActive,
                            child: child!,
                          ),
                        );
                      },
                      child: view,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    return widget.navigationItems.indexWhere((item) => item.label == pageLabel);
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<PageLabel>) {
          return null;
        }
        final index = widget.navigationItems.indexWhere(
          (item) => item.label == key.value,
        );
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(
    this.context, {
    this.transparent = false,
    double height = AndroidAppearanceTokens.materialNavigationBarHeight,
  }) : super(
         height: height,
         elevation: 3.0,
         labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
       );

  final BuildContext context;
  final bool transparent;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor =>
      transparent ? Colors.transparent : _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return IconThemeData(
        size: 24.0,
        color: states.contains(WidgetState.disabled)
            ? _colors.onSurfaceVariant.opacity38
            : states.contains(WidgetState.selected)
            ? _colors.onSecondaryContainer
            : _colors.onSurfaceVariant,
      );
    });
  }

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => const StadiumBorder();

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      final TextStyle style = _textTheme.labelMedium!;
      return style.apply(
        overflow: TextOverflow.ellipsis,
        color: states.contains(WidgetState.disabled)
            ? _colors.onSurfaceVariant.opacity38
            : states.contains(WidgetState.selected)
            ? _colors.onSurface
            : _colors.onSurfaceVariant,
      );
    });
  }
}

class _NavigationBarDefaultsMiuix extends _NavigationBarDefaultsM3 {
  _NavigationBarDefaultsMiuix(super.context, {required super.transparent})
    : super(height: AndroidAppearanceTokens.miuixNavigationBarHeight);

  @override
  Color? get indicatorColor => _colors.primary.withValues(alpha: 0.14);

  @override
  ShapeBorder? get indicatorShape => const RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(18)),
  );

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme {
    return WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 26,
        color: selected
            ? _colors.onSurface
            : _colors.onSurface.withValues(alpha: 0.4),
      );
    });
  }

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle {
    return WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return _textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected
            ? _colors.onSurface
            : _colors.onSurface.withValues(alpha: 0.4),
        overflow: TextOverflow.ellipsis,
      );
    });
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await globalState.container
              .read(systemActionProvider.notifier)
              .handleClose();
        }
        return false;
      },
      child: child,
    );
  }
}
