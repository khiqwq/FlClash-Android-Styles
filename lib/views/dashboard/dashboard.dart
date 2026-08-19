import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/core_status_button.dart';
import 'widgets/start_button.dart';

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

const _maxCrossAxisCount = 16;
const _maxGridWidth = 280.0 * _maxCrossAxisCount / 4;

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  void dispose() {
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  List<Widget> _buildActions(bool isEdit) {
    return [
      if (!isEdit && coreLib == null) const CoreStatusButton(),
      if (isEdit)
        ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, addedChildren, child) {
            if (addedChildren.isEmpty) {
              return Container();
            }
            return child!;
          },
          child: IconButton(
            onPressed: () {
              _showAddWidgetsModal();
            },
            icon: const Icon(Icons.add_circle),
          ),
        ),
      FadeRotationScaleBox(
        child: isEdit
            ? IconButton(
                key: const ValueKey(true),
                icon: const Icon(Icons.save, key: ValueKey('save-icon')),
                onPressed: _handleSaveAndExit,
              )
            : IconButton(
                key: const ValueKey(false),
                icon: const Icon(Icons.edit, key: ValueKey('edit-icon')),
                onPressed: _handleEnterEdit,
              ),
      ),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: context.appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  void _handleEnterEdit() {
    if (_isEditNotifier.value) {
      return;
    }
    _isEditNotifier.value = true;
  }

  void _handleExitEdit() {
    if (!_isEditNotifier.value) {
      return;
    }
    final dashboardWidgets = _getDashboardWidgets(key.currentState);
    if (dashboardWidgets != null) {
      _saveDashboardWidgets(dashboardWidgets);
    }
    _isEditNotifier.value = false;
  }

  Future<void> _handleSaveAndExit() async {
    if (!_isEditNotifier.value) {
      return;
    }
    await _handleSave();
    if (mounted) {
      _isEditNotifier.value = false;
    }
  }

  Future<void> _handleSave() async {
    final currentState = key.currentState;
    if (currentState == null) {
      return;
    }
    if (!mounted || currentState.snapshotChildren.isEmpty) {
      return;
    }
    final transformCompleted = await currentState.isTransformCompleter;
    if (!transformCompleted ||
        !mounted ||
        !currentState.mounted ||
        !identical(key.currentState, currentState)) {
      return;
    }
    final dashboardWidgets = _getDashboardWidgets(currentState);
    if (dashboardWidgets == null) {
      return;
    }
    _saveDashboardWidgets(dashboardWidgets);
  }

  List<DashboardWidget>? _getDashboardWidgets(SuperGridState? currentState) {
    if (currentState == null) {
      return null;
    }
    final children = currentState.snapshotChildren;
    if (children.isEmpty) {
      return null;
    }
    return children.map(DashboardWidget.getDashboardWidget).toList();
  }

  void _saveDashboardWidgets(List<DashboardWidget> dashboardWidgets) {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(dashboardWidgets: dashboardWidgets));
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final isMiuix =
        Theme.of(context).extension<AppearanceTheme>()?.isMiuix == true;
    final spacing = 14.mAp;
    final children = [
      ...dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) =>
                !children.contains(item.widget) &&
                item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget)
          .toList();
    });
    return _buildIsEdit(
      (isEdit) => CommonScaffold(
        title: context.appLocalizations.dashboard,
        actions: _buildActions(isEdit),
        floatingActionButton: const StartButton(),
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16).copyWith(bottom: 88),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  if (isMiuix && !isEdit) ...[
                    const _MiuixCoreStatusCard(),
                    SizedBox(height: spacing),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxGridWidth),
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        final columns = min(
                          max(4 * ((constraints.maxWidth / 280).ceil()), 8),
                          _maxCrossAxisCount,
                        );
                        return isEdit
                            ? BackLayerScope(
                                onBack: _handleExitEdit,
                                child: SuperGrid(
                                  key: key,
                                  crossAxisCount: columns,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                  children: children,
                                  onUpdate: () {
                                    _handleSave();
                                  },
                                ),
                              )
                            : Grid(
                                crossAxisCount: columns,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                children: children,
                              );
                      },
                    ),
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

class _MiuixCoreStatusCard extends ConsumerWidget {
  const _MiuixCoreStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStart = ref.watch(isStartProvider);
    final coreStatus = ref.watch(coreStatusProvider);
    final status = isStart ? coreStatus : CoreStatus.disconnected;
    final accent = switch (status) {
      CoreStatus.connected => const Color(0xFF36C96B),
      CoreStatus.connecting => context.colorScheme.primary,
      CoreStatus.disconnected => context.colorScheme.error,
    };
    final statusLabel = switch (status) {
      CoreStatus.connected => context.appLocalizations.connected,
      CoreStatus.connecting => context.appLocalizations.connecting,
      CoreStatus.disconnected => context.appLocalizations.disconnected,
    };
    final icon = switch (status) {
      CoreStatus.connected => Icons.check_circle_outline_rounded,
      CoreStatus.connecting => Icons.sync_rounded,
      CoreStatus.disconnected => Icons.power_settings_new_rounded,
    };
    final background = Color.alphaBlend(
      accent.withValues(
        alpha: Theme.brightnessOf(context) == Brightness.dark ? 0.2 : 0.14,
      ),
      context.colorScheme.surfaceContainer,
    );
    final cardHeight = max(
      144.0,
      128 * MediaQuery.textScalerOf(context).scale(1),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxGridWidth),
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: cardHeight,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -26,
                child: Icon(
                  icon,
                  size: 142,
                  color: accent.withValues(alpha: 0.58),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.appLocalizations.coreStatus,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: context.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (isStart)
                        Text(
                          utils.getTimeText(ref.watch(runTimeProvider)),
                          style: context.textTheme.titleMedium?.copyWith(
                            color: context.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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

class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: const EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
