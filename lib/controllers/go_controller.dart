import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:rwkv_mobile_flutter/rwkv_mobile_flutter.dart';
import 'package:rwkv_mobile_flutter/to_rwkv.dart' as to_rwkv;
import 'dart:math';

import 'package:rwkv_mobile_flutter/types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
// import 'package:sentry_flutter/sentry_flutter.dart';

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

  /// Send message to RWKV isolate
  SendPort? _sendPort; //比如发送停止，发送prompt等

  /// Receive message from RWKV isolate
  late final _receivePort =
      ReceivePort(); //主要接收子isolate发送来的消息，比如生成的token，或者子的sendport发送过来后给_sendPort赋值

  final RxInt prefillSpeed = 0.obs;
  final RxInt decodeSpeed = 0.obs;
  bool isGenerating = false;
  late Completer<void> _initRuntimeCompleter = Completer<void>();
  Timer? _getTokensTimer;
  String prompt = """
 <input>
· · · · · · · · 
· · · · · · · · 
· · · ○ ● · · · 
· · · ● ● ● · · 
· · · · · · · · 
· · · · · · · · 
NEXT ○ 
MAX_WIDTH-1
MAX_DEPTH-1
</input> """;
  @override
  void onInit() {
    super.onInit();
    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        debugPrint("receive SendPort: $message");
      } else {
        debugPrint("receive message: $message");
        if (!isGenerating) {
          isGenerating = true;
          generate(prompt);
        }
      }
    });
    loadGoModel();
  }

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
    'i',
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
    // 't',
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
    'I',
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
    // 'T',
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

  ///  加载围棋的模型
  Future<void> loadGoModel() async {
    prefillSpeed.value = 0;
    decodeSpeed.value = 0;

    late final String modelPath;
    late final Backend backend;

    final tokenizerPath = await fromAssetsToTemp(
      "assets/config/othello/b_othello_vocab.txt",
    );

    if (Platform.isIOS || Platform.isMacOS) {
      modelPath = await fromAssetsToTemp(
        "assets/model/othello/rwkv7_othello_26m_L10_D448_extended.st",
      );
      backend = Backend.webRwkv;
    } else {
      modelPath = await fromAssetsToTemp(
        "assets/model/othello/rwkv7_othello_26m_L10_D448_extended-ncnn.bin",
      );
      await fromAssetsToTemp(
        "assets/model/othello/rwkv7_othello_26m_L10_D448_extended-ncnn.param",
      );
      backend = Backend.ncnn;
    }

    final rootIsolateToken = RootIsolateToken.instance;

    if (_sendPort != null) {
      send(
        to_rwkv.ReInitRuntime(
          modelPath: modelPath,
          backend: backend,
          tokenizerPath: tokenizerPath,
          latestRuntimeAddress: 0,
        ),
      );
    } else {
      final options = StartOptions(
        modelPath: modelPath,
        tokenizerPath: tokenizerPath,
        backend: backend,
        sendPort: _receivePort.sendPort,
        rootIsolateToken: rootIsolateToken!,
        latestRuntimeAddress: 0,
      );
      await RWKVMobile().runIsolate(options);
    }

    while (_sendPort == null) {
      debugPrint("waiting for sendPort...");
      await Future.delayed(const Duration(milliseconds: 50));
    }

    send(to_rwkv.GetLatestRuntimeAddress());

    // P.app.demoType.q = DemoType.othello;

    send(to_rwkv.SetMaxLength(64000));
    send(
      to_rwkv.SetSamplerParams(
        temperature: 1.0,
        topK: 1,
        topP: 1.0,
        presencePenalty: .0,
        frequencyPenalty: .0,
        penaltyDecay: .0,
      ),
    );
    send(to_rwkv.SetGenerationStopToken(0));
    send(to_rwkv.ClearStates());
  }

  Future<String> fromAssetsToTemp(
    String assetsPath, {
    String? targetPath,
  }) async {
    try {
      final data = await rootBundle.load(assetsPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, targetPath ?? assetsPath));
      await tempFile.create(recursive: true);
      await tempFile.writeAsBytes(data.buffer.asUint8List());
      return tempFile.path;
    } catch (e) {
      debugPrint("$e");
      return "";
    }
  }

  Future<void> clearStates() async {
    prefillSpeed.value = 0;
    decodeSpeed.value = 0;
    final sendPort = _sendPort;
    if (sendPort == null) {
      debugPrint("sendPort is null");
      return;
    }
    // if (currentModel.q == null) {
    //   qqw("currentModel is null, clean states ignored");
    //   return;
    // }
    send(to_rwkv.ClearStates());
  }

  void send(to_rwkv.ToRWKV toRwkv) {
    final sendPort = _sendPort;
    if (sendPort == null) {
      debugPrint("sendPort is null");
      return;
    }
    sendPort.send(toRwkv);
    return;
  }

  Future<void> stop() async => send(to_rwkv.Stop());

  Future<void> reInitRuntime({
    required String modelPath,
    required Backend backend,
    required String tokenizerPath,
  }) async {
    prefillSpeed.value = 0;
    decodeSpeed.value = 0;
    _initRuntimeCompleter = Completer<void>();
    send(
      to_rwkv.ReInitRuntime(
        modelPath: modelPath,
        backend: backend,
        tokenizerPath: tokenizerPath,
        latestRuntimeAddress: 0,
      ),
    );
    return _initRuntimeCompleter.future;
  }

  /// 直接在 ffi+cpp 线程中进行推理工作, 也就是说, 会让 ffi 线程不接受任何新的 event
  Future<void> generate(String prompt) async {
    prefillSpeed.value = 0;
    decodeSpeed.value = 0;
    final sendPort = _sendPort;
    if (sendPort == null) {
      debugPrint("sendPort is null");
      return;
    }
    debugPrint("to_rwkv.SudokuOthelloGenerate: $prompt");
    send(to_rwkv.SudokuOthelloGenerate(prompt));

    // if (_getTokensTimer != null) {
    //   _getTokensTimer!.cancel();
    // }

    // _getTokensTimer = Timer.periodic(const Duration(milliseconds: 20), (
    //   timer,
    // ) async {
    //   send(to_rwkv.GetResponseBufferIds());
    //   send(to_rwkv.GetPrefillAndDecodeSpeed());
    //   send(to_rwkv.GetResponseBufferContent());
    //   await Future.delayed(const Duration(milliseconds: 1000));
    //   send(to_rwkv.GetIsGenerating());
    // });
  }
}
