// ignore_for_file: deprecated_member_use

library vs_scrollbar;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class VsScrollbarStyle {
  /// The hoverThickness of the VsScrollbar thumb.
  /// default value is 12.0 pixels.
  final double hoverThickness;

  /// The thickness of the VsScrollbar thumb.
  /// default thickness of 8.0 pixels.
  final double thickness;

  /// The radius of the VsScrollbar thumb.
  /// default [Radius.circular] of 8.0 pixels.
  final Radius radius;

  /// The color of the VsScrollbar thumb.
  final Color? color;

  const VsScrollbarStyle(
      {this.radius = _kScrollbarRadius,
      this.thickness = _kScrollbarThickness,
      this.hoverThickness = _kScrollbarThicknessWithTrack,
      this.color});
}

const VsScrollbarStyle _kScrollbarStyle = VsScrollbarStyle();
const double _kScrollbarThickness = 8.0;
const double _kScrollbarThicknessWithTrack = 12.0;
const double _kScrollbarMargin = 2.0;
const double _kScrollbarMinLength = 48.0;
const Radius _kScrollbarRadius = Radius.circular(8.0);
const Duration _kScrollbarFadeDuration = Duration(milliseconds: 300);
const Duration _kScrollbarTimeToFade = Duration(milliseconds: 600);

/// To add a VsScrollbar to a [ScrollView], wrap the scroll view
/// widget in a [VsScrollbar] widget.
///
/// The color of the VsScrollbar will change when dragged. A hover animation is
/// also triggered when used on web and desktop platforms. A VsScrollbar track
/// can also been drawn when triggered by a hover event, which is controlled by
/// [showTrackOnHover]. The thickness of the track and VsScrollbar thumb will
/// become larger when hovering, unless overridden by [hoverThickness].
///
/// See also:
///
///  * [RawScrollbar], a basic VsScrollbar that fades in and out, extended
///    by this class to add more animations and behaviors.
///  * [ScrollbarTheme], which configures the VsScrollbar's appearance.
///  * [ListView], which displays a linear, scrollable list of children.
///  * [GridView], which displays a 2 dimensional, scrollable array of children.
class VsScrollbar extends StatefulWidget {
  /// Creates a material design VsScrollbar that by default will connect to the
  /// closest Scrollable descendant of [child].
  ///
  /// The [child] should be a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  ///
  /// If the [controller] is null, the default behavior is to
  /// enable VsScrollbar dragging using the [PrimaryScrollController].
  ///
  const VsScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.style = _kScrollbarStyle,
    this.scrollbarFadeDuration,
    this.scrollbarTimeToFade,
    this.isAlwaysShown,
    this.showTrackOnHover,
    this.notificationPredicate,
  });

  /// {@macro flutter.widgets.VsScrollbar.child}
  final Widget child;

  /// {@macro flutter.widgets.VsScrollbar.controller}
  final ScrollController? controller;

  /// {@macro flutter.widgets.VsScrollbar.isAlwaysShown}
  final bool? isAlwaysShown;

  /// If this property is null, then [ScrollbarThemeData.showTrackOnHover] of
  /// [ThemeData.scrollbarTheme] is used. If that is also null, the default value
  /// is false.
  final bool? showTrackOnHover;

  ///Style Property for VsScrollbar
  final VsScrollbarStyle style;

  /// {@macro flutter.widgets.VsScrollbar.notificationPredicate}
  final ScrollNotificationPredicate? notificationPredicate;

  /// default 600ms
  final Duration? scrollbarTimeToFade;

  /// default 300ms
  final Duration? scrollbarFadeDuration;

  @override
  // ignore: library_private_types_in_public_api
  _ScrollbarState createState() => _ScrollbarState();
}

class _ScrollbarState extends State<VsScrollbar> {
  @override
  Widget build(BuildContext context) {
    return _MaterialScrollbar(
      controller: widget.controller,
      isAlwaysShown: widget.isAlwaysShown,
      showTrackOnHover: widget.showTrackOnHover,
      hoverThickness: widget.style.hoverThickness,
      thickness: widget.style.thickness,
      radius: widget.style.radius,
      color: widget.style.color,
      notificationPredicate: widget.notificationPredicate,
      child: widget.child,
    );
  }
}

class _MaterialScrollbar extends RawScrollbar {
  const _MaterialScrollbar({
    required super.child,
    super.controller,
    bool? isAlwaysShown,
    this.showTrackOnHover,
    this.hoverThickness,
    this.color,
    this.scrollbarFadeDuration,
    this.scrollbarTimeToFade,
    super.thickness,
    super.radius,
    ScrollNotificationPredicate? notificationPredicate,
  }) : super(
          thumbVisibility: isAlwaysShown,
          fadeDuration: scrollbarFadeDuration ?? _kScrollbarFadeDuration,
          timeToFade: scrollbarTimeToFade ?? _kScrollbarTimeToFade,
          pressDuration: Duration.zero,
          notificationPredicate:
              notificationPredicate ?? defaultScrollNotificationPredicate,
        );
  final Duration? scrollbarTimeToFade;
  final Duration? scrollbarFadeDuration;

  final Color? color;
  final bool? showTrackOnHover;
  final double? hoverThickness;

  @override
  _MaterialScrollbarState createState() => _MaterialScrollbarState();
}

class _MaterialScrollbarState extends RawScrollbarState<_MaterialScrollbar> {
  late AnimationController _hoverAnimationController;
  bool _dragIsActive = true;
  bool _hoverIsActive = false;
  late ColorScheme _colorScheme;
  late ScrollbarThemeData _scrollbarTheme;
  // On Android, scrollbars should match native appearance.
  late bool _useAndroidScrollbar;

  @override
  bool get showScrollbar =>
      widget.thumbVisibility ??
      _scrollbarTheme.thumbVisibility?.resolve({WidgetState.disabled}) ??
      false;

  bool get _showTrackOnHover => widget.showTrackOnHover ?? false;

  Set<WidgetState> get _states => <WidgetState>{
        if (_dragIsActive) WidgetState.dragged,
        if (_hoverIsActive) WidgetState.hovered,
      };

  WidgetStateProperty<Color> get _thumbColor {
    final Color onSurface = widget.color ?? _colorScheme.onSurface;
    late Color dragColor;
    late Color hoverColor;
    late Color idleColor;
    dragColor = onSurface.withOpacity(0.9);
    hoverColor = onSurface.withOpacity(0.75);
    idleColor = onSurface.withOpacity(0.5);

    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.dragged)) {
        return _scrollbarTheme.thumbColor?.resolve(states) ?? dragColor;
      }

      // If the track is visible, the thumb color hover animation is ignored and
      // changes immediately.
      if (states.contains(WidgetState.hovered) && _showTrackOnHover) {
        return _scrollbarTheme.thumbColor?.resolve(states) ?? hoverColor;
      }

      return Color.lerp(
        _scrollbarTheme.thumbColor?.resolve(states) ?? idleColor,
        _scrollbarTheme.thumbColor?.resolve(states) ?? hoverColor,
        _hoverAnimationController.value,
      )!;
    });
  }

  WidgetStateProperty<Color> get _trackColor {
    final Color onSurface = widget.color ?? _colorScheme.onSurface;

    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.hovered) && _showTrackOnHover) {
        return _scrollbarTheme.trackColor?.resolve(states) ??
            onSurface.withOpacity(0.05);
      }
      return const Color(0x00000000);
    });
  }

  WidgetStateProperty<Color> get _trackBorderColor {
    final Color onSurface = widget.color ?? _colorScheme.onSurface;

    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.hovered) && _showTrackOnHover) {
        return _scrollbarTheme.trackBorderColor?.resolve(states) ??
            onSurface.withOpacity(0.1);
      }
      return const Color(0x00000000);
    });
  }

  WidgetStateProperty<double> get _thickness {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.hovered) && _showTrackOnHover) {
        return widget.hoverThickness ??
            _scrollbarTheme.thickness?.resolve(states) ??
            _kScrollbarThicknessWithTrack;
      }
      // The default VsScrollbar thickness is smaller on mobile.
      return widget.thickness ??
          _scrollbarTheme.thickness?.resolve(states) ??
          (_kScrollbarThickness / (_useAndroidScrollbar ? 2 : 1));
    });
  }

  @override
  void initState() {
    super.initState();
    _hoverAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimationController.addListener(() {
      updateScrollbarPainter();
    });
  }

  @override
  void didChangeDependencies() {
    final ThemeData theme = Theme.of(context);
    _colorScheme = theme.colorScheme;
    _scrollbarTheme = theme.scrollbarTheme;
    switch (theme.platform) {
      case TargetPlatform.android:
        _useAndroidScrollbar = true;
        break;
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        _useAndroidScrollbar = false;
        break;
    }
    super.didChangeDependencies();
  }

  @override
  void updateScrollbarPainter() {
    scrollbarPainter
      ..color = _thumbColor.resolve(_states)
      ..trackColor = _trackColor.resolve(_states)
      ..trackBorderColor = _trackBorderColor.resolve(_states)
      ..textDirection = Directionality.of(context)
      ..thickness = _thickness.resolve(_states)
      ..radius = widget.radius ??
          _scrollbarTheme.radius ??
          (_useAndroidScrollbar ? null : _kScrollbarRadius)
      ..crossAxisMargin = _scrollbarTheme.crossAxisMargin ??
          (_useAndroidScrollbar ? 0.0 : _kScrollbarMargin)
      ..mainAxisMargin = _scrollbarTheme.mainAxisMargin ?? 0.0
      ..minLength = _scrollbarTheme.minThumbLength ?? _kScrollbarMinLength
      ..padding = const EdgeInsets.all(0);
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    setState(() {
      _dragIsActive = true;
    });
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    setState(() {
      _dragIsActive = false;
    });
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    // Check if the position of the pointer falls over the painted VsScrollbar
    if (isPointerOverScrollbar(event.position, PointerDeviceKind.mouse)) {
      // Pointer is hovering over the VsScrollbar
      setState(() {
        _hoverIsActive = true;
      });
      _hoverAnimationController.forward();
    } else if (_hoverIsActive) {
      // Pointer was, but is no longer over painted VsScrollbar.
      setState(() {
        _hoverIsActive = false;
      });
      _hoverAnimationController.reverse();
    }
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    setState(() {
      _hoverIsActive = false;
    });
    _hoverAnimationController.reverse();
  }

  @override
  void dispose() {
    _hoverAnimationController.dispose();
    super.dispose();
  }
}
