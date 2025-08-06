import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:math';

// 棋子类型枚举
enum StoneType { empty, black, white }

// 坐标类
class Position {
  final int row;
  final int col;

  Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '($row, $col)';
}

class GoController extends GetxController {
  // 棋盘大小
  static const int boardSize = 19;

  // 棋盘状态
  final RxList<List<StoneType>> board = List.generate(
    boardSize,
    (i) => List.generate(boardSize, (j) => StoneType.empty),
  ).obs;

  // 当前玩家（黑子先手）
  final RxBool isBlackTurn = true.obs;

  // 游戏状态
  final RxBool gameOver = false.obs;

  // 最后落子位置
  final Rx<Position?> lastMove = Rx<Position?>(null);

  // 吃子计数
  final RxInt blackCaptures = 0.obs; // 黑子吃白子数量
  final RxInt whiteCaptures = 0.obs; // 白子吃黑子数量

  // 坐标标签（a到t，没有i）
  static const List<String> coordinates = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
  ];

  // 大写坐标标签（A到T，没有I）
  static const List<String> upperCoordinates = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
  ];

  // 获取小写坐标标签
  String getCoordinateLabel(int index) {
    if (index >= 0 && index < coordinates.length) {
      return coordinates[index];
    }
    return '';
  }

  // 获取大写坐标标签
  String getUpperCoordinateLabel(int index) {
    if (index >= 0 && index < upperCoordinates.length) {
      return upperCoordinates[index];
    }
    return '';
  }

  // 检查位置是否在棋盘内
  bool isValidPosition(int row, int col) {
    return row >= 0 && row < boardSize && col >= 0 && col < boardSize;
  }

  // 检查位置是否为空
  bool isEmpty(int row, int col) {
    return isValidPosition(row, col) && board[row][col] == StoneType.empty;
  }

  // 获取相邻位置
  List<Position> getAdjacentPositions(int row, int col) {
    List<Position> adjacent = [];
    List<List<int>> directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    for (var direction in directions) {
      int newRow = row + direction[0];
      int newCol = col + direction[1];
      if (isValidPosition(newRow, newCol)) {
        adjacent.add(Position(newRow, newCol));
      }
    }
    return adjacent;
  }

  // 计算气数
  int countLiberties(int row, int col, StoneType stoneType) {
    Set<Position> visited = {};
    return _countLibertiesRecursive(row, col, stoneType, visited);
  }

  int _countLibertiesRecursive(
    int row,
    int col,
    StoneType stoneType,
    Set<Position> visited,
  ) {
    Position pos = Position(row, col);
    if (visited.contains(pos)) return 0;
    visited.add(pos);

    if (!isValidPosition(row, col)) return 0;
    if (board[row][col] == StoneType.empty) return 1;
    if (board[row][col] != stoneType) return 0;

    int liberties = 0;
    List<Position> adjacent = getAdjacentPositions(row, col);

    for (var adj in adjacent) {
      liberties += _countLibertiesRecursive(
        adj.row,
        adj.col,
        stoneType,
        visited,
      );
    }

    return liberties;
  }

  // 检查是否可以落子（提子规则）
  bool canPlaceStone(int row, int col) {
    if (!isEmpty(row, col)) return false;

    // 临时放置棋子
    StoneType currentStone = isBlackTurn.value
        ? StoneType.black
        : StoneType.white;
    board[row][col] = currentStone;

    // 检查是否有气
    bool hasLiberty = countLiberties(row, col, currentStone) > 0;

    // 检查是否可以提子
    bool canCapture = false;
    List<Position> adjacent = getAdjacentPositions(row, col);
    for (var adj in adjacent) {
      StoneType adjacentStone = board[adj.row][adj.col];
      if (adjacentStone != StoneType.empty && adjacentStone != currentStone) {
        if (countLiberties(adj.row, adj.col, adjacentStone) == 0) {
          canCapture = true;
          break;
        }
      }
    }

    // 恢复棋盘状态
    board[row][col] = StoneType.empty;

    return hasLiberty || canCapture;
  }

  // 落子
  void placeStone(int row, int col) {
    if (gameOver.value || !canPlaceStone(row, col)) return;

    // 获取当前棋子颜色
    String stoneColor = isBlackTurn.value ? '黑子' : '白子';

    // 打印上边和左边对应的标签以及棋子颜色
    String label = upperCoordinates[col] + coordinates[row];
    print('$stoneColor落子位置: $label');

    // 放置棋子
    StoneType currentStone = isBlackTurn.value
        ? StoneType.black
        : StoneType.white;
    board[row][col] = currentStone;
    lastMove.value = Position(row, col);

    // 提子
    _captureStones(row, col, currentStone);

    // 切换玩家
    isBlackTurn.value = !isBlackTurn.value;

    // 检查游戏是否结束
    _checkGameEnd();
  }

  // 提子
  void _captureStones(int row, int col, StoneType currentStone) {
    List<Position> adjacent = getAdjacentPositions(row, col);
    for (var adj in adjacent) {
      StoneType adjacentStone = board[adj.row][adj.col];
      if (adjacentStone != StoneType.empty && adjacentStone != currentStone) {
        if (countLiberties(adj.row, adj.col, adjacentStone) == 0) {
          _removeGroup(adj.row, adj.col, adjacentStone);
        }
      }
    }
  }

  // 移除棋子群
  void _removeGroup(int row, int col, StoneType stoneType) {
    if (!isValidPosition(row, col) || board[row][col] != stoneType) return;

    // 计数被吃的棋子
    if (stoneType == StoneType.white) {
      blackCaptures.value++;
    } else if (stoneType == StoneType.black) {
      whiteCaptures.value++;
    }

    board[row][col] = StoneType.empty;

    List<Position> adjacent = getAdjacentPositions(row, col);
    for (var adj in adjacent) {
      _removeGroup(adj.row, adj.col, stoneType);
    }
  }

  // AI落子
  void aiMove() {
    if (gameOver.value) return;

    // 简单的AI策略：随机选择有效位置
    List<Position> validMoves = [];
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (canPlaceStone(i, j)) {
          validMoves.add(Position(i, j));
        }
      }
    }

    if (validMoves.isNotEmpty) {
      Random random = Random();
      Position move = validMoves[random.nextInt(validMoves.length)];
      placeStone(move.row, move.col);
    }
  }

  // 检查游戏结束
  void _checkGameEnd() {
    // 简单的结束条件：棋盘满了或者没有有效移动
    bool hasValidMoves = false;
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (canPlaceStone(i, j)) {
          hasValidMoves = true;
          break;
        }
      }
      if (hasValidMoves) break;
    }

    if (!hasValidMoves) {
      gameOver.value = true;
    }
  }

  // 重新开始游戏
  void resetGame() {
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        board[i][j] = StoneType.empty;
      }
    }
    isBlackTurn.value = true;
    gameOver.value = false;
    lastMove.value = null;
    blackCaptures.value = 0;
    whiteCaptures.value = 0;
  }

  // 获取棋子颜色
  Color getStoneColor(int row, int col) {
    switch (board[row][col]) {
      case StoneType.black:
        return Colors.black;
      case StoneType.white:
        return Colors.white;
      case StoneType.empty:
        return Colors.transparent;
    }
  }

  // 检查是否是最后落子位置
  bool isLastMove(int row, int col) {
    return lastMove.value != null &&
        lastMove.value!.row == row &&
        lastMove.value!.col == col;
  }
}
