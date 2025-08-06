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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(
                () => Text(
                  '当前玩家: ${controller.isBlackTurn.value ? "黑子" : "白子"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          const SizedBox(height: 8),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '黑吃白: ${controller.blackCaptures.value}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Text(
                    '白吃黑: ${controller.whiteCaptures.value}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 根据屏幕大小动态调整
          double screenWidth = MediaQuery.of(context).size.width;
          bool isMobile = screenWidth < 600;

          // 计算棋盘实际大小，确保不超出可用空间
          double maxWidth = constraints.maxWidth;
          double maxHeight = constraints.maxHeight;
          double boardSize = maxWidth < maxHeight ? maxWidth : maxHeight;

          // 为坐标标签留出空间
          double coordinateSpace = isMobile ? 16.0 : 20.0;
          double availableSize = boardSize - 2 * coordinateSpace;

          return Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                children: [
                  // 棋盘背景
                  Container(color: const Color(0xFFDEB887)),
                  // 网格线
                  Padding(
                    padding: EdgeInsets.all(coordinateSpace),
                    child: CustomPaint(
                      painter: GoBoardPainter(),
                      size: Size.infinite,
                    ),
                  ),
                  // 棋子
                  Padding(
                    padding: EdgeInsets.all(coordinateSpace),
                    child: Obx(() {
                      controller.gameOver.value;
                      controller.isBlackTurn.value;
                      return _buildStonesWithPadding(
                        coordinateSpace,
                        availableSize,
                      );
                    }),
                  ),
                  // 上坐标标签 A-S
                  _buildTopCoordinates(coordinateSpace, availableSize),
                  // 下坐标标签 A-S
                  _buildBottomCoordinates(coordinateSpace, availableSize),
                  // 左坐标标签 1-19
                  _buildLeftCoordinates(coordinateSpace, availableSize),
                  // 右坐标标签 1-19
                  _buildRightCoordinates(coordinateSpace, availableSize),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStonesWithPadding(double padding, double availableSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕大小动态调整棋子大小
        double screenWidth = MediaQuery.of(context).size.width;
        double stoneRadius = screenWidth < 600 ? 8.0 : 12.0; // 手机屏幕棋子更小

        double cellSize = availableSize / 18;

        return Stack(
          children: List.generate(
            19,
            (row) => List.generate(
              19,
              (col) => Positioned(
                left: col * cellSize - stoneRadius,
                top: row * cellSize - stoneRadius,
                child: GestureDetector(
                  onTap: () => _onStoneTap(row, col),
                  child: Container(
                    width: stoneRadius * 2,
                    height: stoneRadius * 2,
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

  Widget _buildTopCoordinates(double padding, double availableSize) {
    return Positioned(
      top: 0,
      left: 0, // 覆盖整个棋盘宽度
      right: 0, // 覆盖整个棋盘宽度
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double cellSize = availableSize / 18;

          return Stack(
            children: List.generate(19, (index) {
              return Positioned(
                left: padding + index * cellSize - 4, // 使用cellSize变量
                top: 2,
                child: Text(
                  controller.getUpperCoordinateLabel(index), // A-S
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildBottomCoordinates(double padding, double availableSize) {
    return Positioned(
      bottom: 0,
      left: 0, // 覆盖整个棋盘宽度
      right: 0, // 覆盖整个棋盘宽度
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double cellSize = availableSize / 18;

          return Stack(
            children: List.generate(19, (index) {
              return Positioned(
                left: padding + index * cellSize - 4, // 使用cellSize变量
                bottom: 2,
                child: Text(
                  controller.getUpperCoordinateLabel(index), // A-S
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildLeftCoordinates(double padding, double availableSize) {
    return Positioned(
      left: 0,
      top: 0, // 覆盖整个棋盘高度
      bottom: 0, // 覆盖整个棋盘高度
      width: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double cellSize = availableSize / 18;

          return Stack(
            children: List.generate(19, (index) {
              return Positioned(
                top: padding + index * cellSize - 6, // 使用cellSize变量
                left: 0,
                right: 0,
                child: Text(
                  controller.getCoordinateLabel(index), // 使用小写a-t
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildRightCoordinates(double padding, double availableSize) {
    return Positioned(
      right: 0,
      top: 0, // 覆盖整个棋盘高度
      bottom: 0, // 覆盖整个棋盘高度
      width: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double cellSize = availableSize / 18;

          return Stack(
            children: List.generate(19, (index) {
              return Positioned(
                top: padding + index * cellSize - 6, // 使用cellSize变量
                left: 0,
                right: 0,
                child: Text(
                  controller.getCoordinateLabel(index), // 使用小写a-t
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              );
            }),
          );
        },
      ),
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

    // 直接使用可用大小，因为已经被Padding组件包围
    double cellSize = size.width / 18;

    // 绘制垂直线
    for (int i = 0; i <= 18; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, 18 * cellSize),
        paint,
      );
    }

    // 绘制水平线
    for (int i = 0; i <= 18; i++) {
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(18 * cellSize, i * cellSize),
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
