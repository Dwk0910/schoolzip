import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

typedef NativeHomeAction = void Function(String action, dynamic value);

/// Sends data/actions only. UIKit owns every screen, scroll position and transition.
class NativeHomeBridge {
  NativeHomeBridge._() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'ready') {
        flush();
        return;
      }
      if (call.method == 'event') {
        final event = Map<String, dynamic>.from(call.arguments as Map);
        actions[event['page']]?.call(event['action'] as String, event['value']);
      }
    });
  }
  static final instance = NativeHomeBridge._();
  final channel = const MethodChannel('schoolzip/home');
  final actions = <String, NativeHomeAction>{};
  final ready = <String, VoidCallback>{};
  final models = <String, Map<String, dynamic>>{};
  final encoded = <String, String>{};
  void publish(String page, Map<String, dynamic> model) {
    final value = jsonEncode(model);
    if (encoded[page] == value) return;
    encoded[page] = value;
    models[page] = model;
    WidgetsBinding.instance.addPostFrameCallback((_) => send(page));
  }

  Future<void> send(String page) async {
    final model = models[page];
    if (model == null) return;
    try {
      await channel.invokeMethod<void>('update', {
        'page': page,
        'model': model,
      });
    } on MissingPluginException {
      /* The native host will request the latest models. */
    }
  }

  void flush() {
    for (final page in models.keys.toList()) {
      send(page);
    }
    for (final callback in ready.values.toList()) {
      callback();
    }
  }

  void remove(String page, NativeHomeAction action) {
    if (actions[page] != action) return;
    actions.remove(page);
    models.remove(page);
    encoded.remove(page);
  }
}

class NativePageModel extends StatefulWidget {
  final String page;
  final Map<String, dynamic> model;
  final NativeHomeAction onAction;
  const NativePageModel({
    super.key,
    required this.page,
    required this.model,
    required this.onAction,
  });
  @override
  State<NativePageModel> createState() => _NativePageModelState();
}

class _NativePageModelState extends State<NativePageModel> {
  void dispatch(String action, dynamic value) => widget.onAction(action, value);
  @override
  Widget build(BuildContext context) {
    final bridge = NativeHomeBridge.instance;
    bridge.actions[widget.page] = dispatch;
    bridge.publish(widget.page, widget.model);
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    NativeHomeBridge.instance.remove(widget.page, dispatch);
    super.dispose();
  }
}
