import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Makes mouse-wheel scrolling feel continuous on desktop without changing
/// touch scrolling or the platform's normal drag physics.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
    this.smoothWheel,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final Duration duration;
  final Curve curve;
  final bool? smoothWheel;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
    duration: duration,
    curve: curve,
    smoothWheel: smoothWheel,
  );
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    required this.duration,
    required this.curve,
    required this.smoothWheel,
    super.oldPosition,
    super.debugLabel,
  });

  final Duration duration;
  final Curve curve;
  final bool? smoothWheel;
  double? _wheelTarget;

  @override
  void pointerScroll(double delta) {
    if (!(smoothWheel ?? defaultTargetPlatform == TargetPlatform.windows)) {
      super.pointerScroll(delta);
      return;
    }

    if (delta == 0 || !hasPixels) return;
    final base = _wheelTarget ?? pixels;
    final target = math.min(
      math.max(base + delta, minScrollExtent),
      maxScrollExtent,
    );
    if (target == base) return;

    _wheelTarget = target;
    animateTo(target, duration: duration, curve: curve).whenComplete(() {
      if (_wheelTarget == target) _wheelTarget = null;
    });
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity is! DrivenScrollActivity) _wheelTarget = null;
    super.beginActivity(newActivity);
  }
}

class SmoothListView extends StatefulWidget {
  const SmoothListView({
    required this.children,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final Clip clipBehavior;

  @override
  State<SmoothListView> createState() => _SmoothListViewState();
}

class _SmoothListViewState extends State<SmoothListView> {
  late final SmoothScrollController _ownedController = SmoothScrollController();

  ScrollController get _controller => widget.controller ?? _ownedController;

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: widget.key,
    controller: _controller,
    padding: widget.padding,
    scrollDirection: widget.scrollDirection,
    reverse: widget.reverse,
    shrinkWrap: widget.shrinkWrap,
    physics: widget.physics,
    keyboardDismissBehavior: widget.keyboardDismissBehavior,
    clipBehavior: widget.clipBehavior,
    children: widget.children,
  );
}

class SmoothListViewBuilder extends StatefulWidget {
  const SmoothListViewBuilder({
    required this.itemBuilder,
    required this.itemCount,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final IndexedWidgetBuilder itemBuilder;
  final int? itemCount;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final Clip clipBehavior;

  @override
  State<SmoothListViewBuilder> createState() => _SmoothListViewBuilderState();
}

class _SmoothListViewBuilderState extends State<SmoothListViewBuilder> {
  late final SmoothScrollController _ownedController = SmoothScrollController();

  ScrollController get _controller => widget.controller ?? _ownedController;

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: widget.key,
    controller: _controller,
    padding: widget.padding,
    scrollDirection: widget.scrollDirection,
    reverse: widget.reverse,
    shrinkWrap: widget.shrinkWrap,
    physics: widget.physics,
    keyboardDismissBehavior: widget.keyboardDismissBehavior,
    clipBehavior: widget.clipBehavior,
    itemCount: widget.itemCount,
    itemBuilder: widget.itemBuilder,
  );
}

class SmoothListViewSeparated extends StatefulWidget {
  const SmoothListViewSeparated({
    required this.itemBuilder,
    required this.separatorBuilder,
    required this.itemCount,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final int itemCount;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final Clip clipBehavior;

  @override
  State<SmoothListViewSeparated> createState() =>
      _SmoothListViewSeparatedState();
}

class _SmoothListViewSeparatedState extends State<SmoothListViewSeparated> {
  late final SmoothScrollController _ownedController = SmoothScrollController();

  ScrollController get _controller => widget.controller ?? _ownedController;

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: widget.key,
    controller: _controller,
    padding: widget.padding,
    scrollDirection: widget.scrollDirection,
    reverse: widget.reverse,
    shrinkWrap: widget.shrinkWrap,
    physics: widget.physics,
    keyboardDismissBehavior: widget.keyboardDismissBehavior,
    clipBehavior: widget.clipBehavior,
    itemCount: widget.itemCount,
    itemBuilder: widget.itemBuilder,
    separatorBuilder: widget.separatorBuilder,
  );
}

class SmoothSingleChildScrollView extends StatefulWidget {
  const SmoothSingleChildScrollView({
    required this.child,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.physics,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final Widget child;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Clip clipBehavior;

  @override
  State<SmoothSingleChildScrollView> createState() =>
      _SmoothSingleChildScrollViewState();
}

class _SmoothSingleChildScrollViewState
    extends State<SmoothSingleChildScrollView> {
  late final SmoothScrollController _ownedController = SmoothScrollController();

  ScrollController get _controller => widget.controller ?? _ownedController;

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: widget.key,
    controller: _controller,
    scrollDirection: widget.scrollDirection,
    reverse: widget.reverse,
    padding: widget.padding,
    physics: widget.physics,
    clipBehavior: widget.clipBehavior,
    child: widget.child,
  );
}
