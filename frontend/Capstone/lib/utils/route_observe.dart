import 'package:flutter/material.dart';
import 'voice_helper.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

mixin SpeakOnPageOpen<T extends StatefulWidget> on State<T>
implements RouteAware {

  String get pageName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    VoiceHelper.speakPage(pageName);
  }
}
