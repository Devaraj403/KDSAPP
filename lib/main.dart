
import 'package:flutter/material.dart';
// import 'package:kids_tv/screens/pos_client_screen.dart';
// import 'package:vinatusoftware/screens/pos_client_screen.dart';
import 'package:kds_tv/screens/pos_client_screen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PosClientScreen(),
    );
  }
}
