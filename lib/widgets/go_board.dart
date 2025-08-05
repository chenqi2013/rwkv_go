import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/go_controller.dart';

class GoBoard extends StatelessWidget {
  final GoController controller = Get.find<GoController>();

  GoBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 游戏信息
          Obx(() => _buildGameInfo()),
          const SizedBox(height: 16),
          // 棋盘
          Expanded(child: _buildBoard()),
          const SizedBox(height: 16),
          // 控制按钮
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '当前玩家: ${controller.isBlackTurn.value ? "黑子" : "白子"}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (controller.gameOver.value)
            const Text(
              '游戏结束',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDEB887), // 棋盘木色
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          children: [
            // 棋盘背景
            Container(color: const Color(0xFFDEB887)),
            // 网格线
            CustomPaint(painter: GoBoardPainter(), size: Size.infinite),
            // 棋子
            Obx(() {
              // 访问可观察变量来触发重建
              controller.isBlackTurn.value;
              return _buildStones();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStones() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double cellSize = constraints.maxWidth / 18;
        return Stack(
          children: List.generate(
            19,
            (row) => List.generate(
              19,
              (col) => Positioned(
                left: col * cellSize - 12,
                top: row * cellSize - 12,
                child: GestureDetector(
                  onTap: () => _onStoneTap(row, col),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStoneColor(row, col),
                    ),
                  ),
                ),
              ),
            ),
          ).expand((widgets) => widgets).toList(),
        );
      },
    );
  }

  Color _getStoneColor(int row, int col) {
    switch (controller.board[row][col]) {
      case StoneType.black:
        return Colors.black;
      case StoneType.white:
        return Colors.white;
      case StoneType.empty:
        return Colors.transparent;
    }
  }

  void _onStoneTap(int row, int col) {
    if (controller.gameOver.value) return;

    // 玩家落子
    controller.placeStone(row, col);

    // AI回合
    if (!controller.gameOver.value && !controller.isBlackTurn.value) {
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.aiMove();
      });
    }
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () => controller.resetGame(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('重新开始'),
        ),
        Obx(
          () => ElevatedButton(
            onPressed: controller.gameOver.value
                ? null
                : () => controller.aiMove(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('AI落子'),
          ),
        ),
      ],
    );
  }
}

// 围棋棋盘绘制器
class GoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double cellSize = size.width / 18;

    // 绘制垂直线
    for (int i = 0; i <= 18; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        paint,
      );
    }

    // 绘制水平线
    for (int i = 0; i <= 18; i++) {
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        paint,
      );
    }

    // 绘制星位点
    Paint starPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    double starRadius = 3.0;

    // 星位点位置（3,3), (3,9), (3,15), (9,3), (9,9), (9,15), (15,3), (15,9), (15,15)
    List<List<int>> starPoints = [
      [3, 3],
      [3, 9],
      [3, 15],
      [9, 3],
      [9, 9],
      [9, 15],
      [15, 3],
      [15, 9],
      [15, 15],
    ];

    for (var point in starPoints) {
      canvas.drawCircle(
        Offset(point[1] * cellSize, point[0] * cellSize),
        starRadius,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
