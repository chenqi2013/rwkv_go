import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/go_controller.dart';
import 'widgets/go_board.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RWKV Go',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const GoGamePage(),
    );
  }
}

class GoGamePage extends StatelessWidget {
  const GoGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 初始化控制器
    Get.put(GoController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('RWKV Go'),
        centerTitle: true,
      ),
      body: GoBoard(),
    );
  }
}
