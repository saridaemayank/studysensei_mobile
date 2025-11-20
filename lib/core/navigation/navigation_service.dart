import 'package:flutter/widgets.dart';

/// Provides a global navigator key so services can perform navigation without a BuildContext.
class NavigationService {
  NavigationService._();

  /// Navigator key attached to the root [MaterialApp].
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

