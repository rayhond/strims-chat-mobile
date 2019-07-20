import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'chat.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.grey[999],
        accentColor: Colors.orange[500],
      ),
      home: new ChatPage(),
    );
  }
}
