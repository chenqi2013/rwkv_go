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
          // 棋盘 - 使用Expanded让棋盘适应剩余空间
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
      child: Padding(
        padding: const EdgeInsets.all(8.0), // 减少内边距
        child: Column(
          children: [
            // 顶部坐标标签
            _buildTopCoordinates(),
            // 棋盘主体 - 使用Expanded让棋盘网格适应剩余空间
            Expanded(
              child: Row(
                children: [
                  // 左侧坐标标签
                  _buildLeftCoordinates(),
                  // 棋盘网格
                  Expanded(child: _buildBoardGrid()),
                  // 右侧坐标标签
                  _buildRightCoordinates(),
                ],
              ),
            ),
            // 底部坐标标签
            _buildBottomCoordinates(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCoordinates() {
    return Row(
      children: [
        const SizedBox(width: 8),
        ...List.generate(
          19,
          (index) => SizedBox(
            width: 16, // 设置宽度
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-4, 0),
                child: Text(
                  controller.getUpperCoordinateLabel(index),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomCoordinates() {
    return Row(
      children: [
        const SizedBox(width: 8),
        ...List.generate(
          19,
          (index) => SizedBox(
            width: 16, // 设置宽度
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-4, 0),
                child: Text(
                  controller.getUpperCoordinateLabel(index),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLeftCoordinates() {
    return Column(
      children: List.generate(
        19,
        (index) => SizedBox(
          height: 16, // 设置高度
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                controller.getCoordinateLabel(18 - index),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightCoordinates() {
    return Column(
      children: List.generate(
        19,
        (index) => SizedBox(
          height: 16, // 设置高度
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                controller.getCoordinateLabel(18 - index),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardGrid() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDEB887),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          children: [
            // 棋盘网格线
            _buildGridLines(),
            // 星位点
            _buildStarPoints(),
            // 棋子
            Obx(() => _buildStones()),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLines() {
    return CustomPaint(painter: GridPainter(), size: Size.infinite);
  }

  Widget _buildStarPoints() {
    return CustomPaint(painter: StarPointsPainter(), size: Size.infinite);
  }

  Widget _buildStones() {
    return Stack(
      children: List.generate(
        19,
        (row) => List.generate(19, (col) => _buildStone(row, col)),
      ).expand((widgets) => widgets).toList(),
    );
  }

  Widget _buildStone(int row, int col) {
    // 计算棋子在交叉点上的位置
    double cellSize = 100.0 / 18; // 每个格子的大小
    double left = col * cellSize - 15; // 15是棋子半径
    double top = row * cellSize - 15;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _onStoneTap(row, col),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: controller.getStoneColor(row, col),
            border: controller.isLastMove(row, col)
                ? Border.all(color: Colors.red, width: 3)
                : null,
            boxShadow: controller.board[row][col] != StoneType.empty
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4.0,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
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

// 网格线绘制器
class GridPainter extends CustomPainter {
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 星位点绘制器
class StarPointsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    double cellSize = size.width / 18;
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
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
