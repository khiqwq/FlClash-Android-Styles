import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          const DashboardState(dashboardWidgets: []),
        ),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(390, 800);
  });

  tearDown(() {
    container.dispose();
  });

  Widget buildApp(Widget child) {
    const appearance = AppearanceTheme(
      isAndroid: true,
      interfaceStyle: InterfaceStyle.miuix,
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: applyAppearanceComponentTheme(
          ThemeData(extensions: const [appearance]),
          appearance,
        ),
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return child!;
        },
        home: child,
      ),
    );
  }

  testWidgets('Miuix settings render grouped preference cards', (tester) async {
    await tester.pumpWidget(buildApp(const ToolsView()));
    await tester.pump();

    expect(find.byType(AdaptiveListSection), findsWidgets);
    final groupedSurface = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(AdaptiveListSection).first,
            matching: find.byType(Material),
          ),
        )
        .where((material) => material.shape is RoundedSuperellipseBorder);
    expect(groupedSurface, isNotEmpty);
  });

  testWidgets('Miuix dashboard adds a prominent core status card', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const DashboardView()));
    await tester.pump();

    final context = tester.element(find.byType(DashboardView));
    expect(find.text(context.appLocalizations.coreStatus), findsWidgets);
    expect(find.text(context.appLocalizations.disconnected), findsWidgets);
    expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
  });

  testWidgets('Miuix dashboard uses authoritative core status', (tester) async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    await tester.pumpWidget(buildApp(const DashboardView()));
    await tester.pump();

    final context = tester.element(find.byType(DashboardView));
    expect(find.text(context.appLocalizations.connecting), findsWidgets);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
  });

  testWidgets('Miuix ListItem preserves explicit caller dimensions', (
    tester,
  ) async {
    const padding = EdgeInsets.fromLTRB(31, 17, 29, 19);
    await tester.pumpWidget(
      buildApp(
        const Scaffold(
          body: ListItem(
            title: Text('Explicit sizing'),
            minTileHeight: 96,
            minVerticalPadding: 24,
            padding: padding,
          ),
        ),
      ),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.minTileHeight, 96);
    expect(tile.minVerticalPadding, 24);
    expect(tile.contentPadding, padding);
  });

  testWidgets('Miuix ListItem defaults use Miuix content padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: ListItem.toggle(title: const Text('Toggle'), value: false),
        ),
      ),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(
      tile.contentPadding,
      const EdgeInsets.symmetric(
        horizontal: AndroidAppearanceTokens.miuixListHorizontalPadding,
      ),
    );
  });

  testWidgets('Miuix dashboard hero adapts to large text', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: DashboardView(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
