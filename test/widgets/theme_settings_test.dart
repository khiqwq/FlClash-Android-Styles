import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(800, 600);
  });

  tearDown(() {
    container.dispose();
  });

  Widget buildApp(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  Finder findListTileByKey(String value) {
    return find.byWidgetPredicate(
      (widget) => widget is ListTile && widget.key == ValueKey(value),
    );
  }

  testWidgets('Android appearance toggles update theme preferences', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const AndroidAppearanceSettings()));
    await tester.pumpAndSettle();
    expect(container.read(themeSettingProvider).predictiveBack, true);
    final disabledLiquidSwitch = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const ValueKey('liquid-glass-toggle')),
        matching: find.byType(Switch),
      ),
    );
    expect(disabledLiquidSwitch.onChanged, isNull);

    await tester.tap(findListTileByKey('blur-toggle'));
    await tester.pump();
    await tester.tap(findListTileByKey('floating-bottom-bar-toggle'));
    await tester.pump();
    await tester.tap(findListTileByKey('liquid-glass-toggle'));
    await tester.pump();

    final theme = container.read(themeSettingProvider);
    expect(theme.blur, true);
    expect(theme.floatingBottomBar, true);
    expect(theme.liquidGlass, true);

    await tester.tap(findListTileByKey('predictive-back-toggle'));
    await tester.pump();
    expect(container.read(themeSettingProvider).predictiveBack, false);
  });

  testWidgets('interface style selector switches between both styles', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const InterfaceStyleSelector()));
    await tester.pumpAndSettle();
    final localizations = AppLocalizations.of(
      tester.element(find.byType(InterfaceStyleSelector)),
    );
    expect(localizations.miuixStyle, 'Miuix');

    await tester.tap(findListTileByKey('interface-style-selector'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(localizations.miuixStyle));
    await tester.pumpAndSettle();

    expect(
      container.read(themeSettingProvider).interfaceStyle,
      InterfaceStyle.miuix,
    );

    await tester.tap(findListTileByKey('interface-style-selector'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(localizations.materialStyle));
    await tester.pumpAndSettle();

    expect(
      container.read(themeSettingProvider).interfaceStyle,
      InterfaceStyle.material,
    );
  });

  testWidgets('Monet color toggle updates the persisted theme setting', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const MonetColorsSetting()));
    await tester.pumpAndSettle();
    final localizations = AppLocalizations.of(
      tester.element(find.byType(MonetColorsSetting)),
    );

    expect(find.text(localizations.enableMonetColors), findsOneWidget);
    expect(container.read(themeSettingProvider).enableMonetColors, true);

    await tester.tap(findListTileByKey('monet-colors-toggle'));
    await tester.pump();

    expect(container.read(themeSettingProvider).enableMonetColors, false);
    expect(container.read(configProvider).themeProps.enableMonetColors, false);
  });

  testWidgets('blur appearance wraps the top bar in a backdrop filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(
          extensions: const [AppearanceTheme(isAndroid: true, blur: true)],
        ),
        home: const CommonScaffold(title: 'Page', body: SizedBox.shrink()),
      ),
    );

    expect(find.byType(AndroidGlassSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
      true,
    );
  });

  testWidgets('Miuix app bar title uses directional start alignment', (
    tester,
  ) async {
    const appearance = AppearanceTheme(
      isAndroid: true,
      interfaceStyle: InterfaceStyle.miuix,
    );
    await tester.pumpWidget(
      MaterialApp(
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
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: CommonScaffold(title: 'Page', body: SizedBox.shrink()),
        ),
      ),
    );

    final titleAlignments = tester
        .widgetList<Align>(
          find.ancestor(of: find.text('Page'), matching: find.byType(Align)),
        )
        .map((align) => align.alignment);
    expect(titleAlignments, contains(AlignmentDirectional.bottomStart));
  });
}
