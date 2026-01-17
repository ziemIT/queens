import 'dart:async'; // <--- 1. Potrzebne do Timera
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CellState { empty, queen, cross }

class CellModel {
  final int row;
  final int col;
  final int zoneId;
  CellState state;
  bool hasError;
  bool isSolution;

  CellModel({
    required this.row,
    required this.col,
    required this.zoneId,
    this.state = CellState.empty,
    this.hasError = false,
    this.isSolution = false,
  });
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // --- KONFIGURACJA ---
  int gridSize = 8;
  final bool isDebugging = false;
  String difficulty = 'easy';
  int currentLevelIndex = 1;
  bool isLoading = true;

  // --- TIMER ---
  Timer? _timer; // Obiekt timera
  Duration _elapsed = Duration.zero; // Przechowuje upływ czasu

  // --- DANE GRY ---
  List<CellModel> board = [];

  final List<Color> zoneColors = [
    Colors.red[100]!,
    Colors.blue[100]!,
    Colors.green[100]!,
    Colors.orange[100]!,
    Colors.purple[100]!,
    Colors.teal[100]!,
    Colors.amber[100]!,
    Colors.brown[100]!,
    Colors.pink[100]!,
    Colors.lime[100]!,
  ];

  @override
  void initState() {
    super.initState();
    _loadLevel(currentLevelIndex);
  }

  @override
  void dispose() {
    _stopTimer(); // <--- Ważne: Sprzątamy timer przy wyjściu z ekranu
    super.dispose();
  }

  // --- OBSŁUGA TIMERA ---
  void _startTimer() {
    _stopTimer(); // Reset poprzedniego
    setState(() {
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
  // ----------------------

  Future<void> _loadLevel(int levelId) async {
    _stopTimer(); // Zatrzymaj stary timer podczas ładowania
    setState(() {
      isLoading = true;
    });

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/levels/$difficulty/level_$levelId.json',
      );
      final data = jsonDecode(jsonString);

      int newSize = data['size'] ?? 8;

      List<List<int>> loadedZones = List<List<int>>.from(
        data['zones'].map((row) => List<int>.from(row)),
      );

      List<dynamic> solutionData = data['solution_queens'];
      Set<String> solutionSet = {};
      for (var point in solutionData) {
        solutionSet.add("${point['row']},${point['col']}");
      }

      List<CellModel> newBoard = [];
      for (int row = 0; row < newSize; row++) {
        for (int col = 0; col < newSize; col++) {
          bool isSol = solutionSet.contains("$row,$col");
          newBoard.add(
            CellModel(
              row: row,
              col: col,
              zoneId: loadedZones[row][col],
              isSolution: isSol,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          gridSize = newSize;
          board = newBoard;
          currentLevelIndex = levelId;
          isLoading = false;
        });
        _startTimer(); // <--- Startujemy timer po załadowaniu
      }
    } catch (e) {
      print("Błąd: $e");
      if (mounted) {
        setState(() {
          board = [];
          isLoading = false;
        });
      }
    }
  }

  void _handleTap(int index) {
    if (isLoading) return;

    setState(() {
      CellModel cell = board[index];
      if (cell.state == CellState.empty) {
        cell.state = CellState.cross;
      } else if (cell.state == CellState.cross) {
        cell.state = CellState.queen;
      } else {
        cell.state = CellState.empty;
      }

      _validateBoard();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkWinCondition();
      });
    });
  }

  void _checkWinCondition() {
    int queensCount = board
        .where((cell) => cell.state == CellState.queen)
        .length;
    bool hasErrors = board.any((cell) => cell.hasError);

    if (queensCount == gridSize && !hasErrors) {
      _stopTimer(); // <--- Zatrzymaj czas po wygranej!
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Gratulacje! 🎉"),
          // Wyświetlamy czas w komunikacie końcowym
          content: Text("Poziom ukończony w czasie: ${_formatTime(_elapsed)}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changeLevel(1);
              },
              child: const Text("Następny poziom"),
            ),
          ],
        );
      },
    );
  }

  void _changeLevel(int offset) {
    int newLevel = currentLevelIndex + offset;
    if (newLevel < 1) newLevel = 1;
    if (newLevel > 50) newLevel = 50;

    if (newLevel != currentLevelIndex) {
      _loadLevel(newLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Zmieniliśmy Title na Column, żeby zmieścić Czas pod spodem
        title: Column(
          children: [
            Text(
              'Level $currentLevelIndex',
              style: const TextStyle(
                fontSize: 24.0, // Trochę mniejszy Level, żeby zmieścić czas
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            // --- WYŚWIETLANIE CZASU ---
            Text(
              _formatTime(_elapsed),
              style: const TextStyle(
                fontSize: 18.0,
                color: Colors.grey, // Szary kolor dla kontrastu
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => _changeLevel(-1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black),
            onPressed: () => _changeLevel(1),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : board.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Błąd: Brak danych poziomu.",
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _loadLevel(currentLevelIndex),
                    child: const Text("Spróbuj ponownie"),
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      crossAxisSpacing: 0,
                      mainAxisSpacing: 0,
                    ),
                    itemCount: board.length,
                    itemBuilder: (context, index) {
                      if (index >= board.length) return const SizedBox();
                      return _buildCell(board[index], index);
                    },
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCell(CellModel cell, int index) {
    Color cellColor = zoneColors[cell.zoneId % zoneColors.length];

    if (isDebugging && cell.isSolution) {
      cellColor = HSLColor.fromColor(cellColor).withLightness(0.6).toColor();
    }

    return GestureDetector(
      onTap: () => _handleTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: cellColor,
          border: cell.hasError
              ? Border.all(color: Colors.red, width: 3)
              : Border.all(color: Colors.black, width: 0.5),
        ),
        child: Center(child: _buildIcon(cell)),
      ),
    );
  }

  Widget _buildIcon(CellModel cell) {
    switch (cell.state) {
      case CellState.queen:
        return Icon(
          Icons.star,
          color: cell.hasError ? Colors.red : Colors.black,
          size: 36,
        );
      case CellState.cross:
        return const Icon(Icons.close, color: Colors.black54, size: 28);
      default:
        return const SizedBox.shrink();
    }
  }

  void _validateBoard() {
    for (var cell in board) cell.hasError = false;

    Map<int, List<CellModel>> rows = {};
    Map<int, List<CellModel>> cols = {};
    Map<int, List<CellModel>> zones = {};

    for (var cell in board) {
      if (cell.state == CellState.queen) {
        rows.putIfAbsent(cell.row, () => []).add(cell);
        cols.putIfAbsent(cell.col, () => []).add(cell);
        zones.putIfAbsent(cell.zoneId, () => []).add(cell);
      }
    }

    void markErrors(Map<int, List<CellModel>> groups) {
      groups.forEach((key, queens) {
        if (queens.length > 1) {
          for (var q in queens) q.hasError = true;
        }
      });
    }

    markErrors(rows);
    markErrors(cols);
    markErrors(zones);

    for (var cell in board) {
      if (cell.state == CellState.queen) {
        _checkNeighbors(cell);
      }
    }
  }

  void _checkNeighbors(CellModel cell) {
    for (int dRow = -1; dRow <= 1; dRow++) {
      for (int dCol = -1; dCol <= 1; dCol++) {
        if (dRow == 0 && dCol == 0) continue;

        int nRow = cell.row + dRow;
        int nCol = cell.col + dCol;

        if (nRow >= 0 && nRow < gridSize && nCol >= 0 && nCol < gridSize) {
          int neighborIndex = nRow * gridSize + nCol;
          CellModel neighbor = board[neighborIndex];

          if (neighbor.state == CellState.queen) {
            cell.hasError = true;
            neighbor.hasError = true;
          }
        }
      }
    }
  }
}
