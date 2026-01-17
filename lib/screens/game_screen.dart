import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'help_screen.dart';

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

  CellModel copy() {
    return CellModel(
      row: row,
      col: col,
      zoneId: zoneId,
      state: state,
      hasError: hasError,
      isSolution: isSolution,
    );
  }
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

  // NOWE: Najwyższy odblokowany poziom (domyślnie 1)
  int maxUnlockedLevel = 1;

  // --- TIMER ---
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // --- DANE GRY ---
  List<CellModel> board = [];

  // Historia ruchów
  List<List<CellModel>> _history = [];

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
    _stopTimer();
    super.dispose();
  }

  // --- OBSŁUGA TIMERA ---
  void _startTimer() {
    _stopTimer(); // Upewniamy się, że nie ma dwóch timerów
    // USUNIĘTO: setState(() { _elapsed = Duration.zero; }); <--- To kasowało czas!

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

  String _formatTime(Duration? duration) {
    final d = duration ?? Duration.zero;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // --- OBSŁUGA POZIOMU ---
  Future<void> _loadLevel(int levelId) async {
    _stopTimer();
    setState(() {
      isLoading = true;
      _elapsed = Duration
          .zero; // <--- PRZENIESIONO TUTAJ: Zerujemy czas tylko przy nowym poziomie
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
          _history.clear();
        });
        _startTimer();
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

  // --- HISTORIA (UNDO/CLEAR) ---
  void _saveToHistory() {
    List<CellModel> snapshot = board.map((cell) => cell.copy()).toList();
    _history.add(snapshot);
    if (_history.length > 50) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      board = _history.removeLast();
      _validateBoard();
    });
  }

  void _clearBoard() {
    _saveToHistory();
    setState(() {
      for (var cell in board) {
        cell.state = CellState.empty;
        cell.hasError = false;
      }
    });
  }

  void _handleTap(int index) {
    if (isLoading) return;
    _saveToHistory();

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
      _stopTimer();
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    // NOWE: Jeśli wygraliśmy na obecnym max poziomie, odblokuj następny
    if (currentLevelIndex == maxUnlockedLevel && maxUnlockedLevel < 50) {
      setState(() {
        maxUnlockedLevel++;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Congrats! 🎉"),
          content: Text("Level finished in: ${_formatTime(_elapsed)}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changeLevel(
                  1,
                ); // To zadziała, bo maxUnlockedLevel został zwiększony
              },
              child: const Text("Next level"),
            ),
          ],
        );
      },
    );
  }

  void _changeLevel(int offset) {
    int newLevel = currentLevelIndex + offset;

    // Walidacja zakresu
    if (newLevel < 1) newLevel = 1;
    if (newLevel > 50) newLevel = 50;

    // NOWE: Nie pozwalaj przejść powyżej odblokowanego poziomu
    if (newLevel > maxUnlockedLevel) return;

    if (newLevel != currentLevelIndex) {
      _loadLevel(newLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sprawdzamy czy możemy iść dalej (dla koloru strzałki)
    bool canGoNext =
        currentLevelIndex < maxUnlockedLevel && currentLevelIndex < 50;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Level $currentLevelIndex',
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              _formatTime(_elapsed),
              style: const TextStyle(
                fontSize: 18.0,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: currentLevelIndex > 1 ? Colors.black : Colors.grey[300],
          ),
          onPressed: currentLevelIndex > 1 ? () => _changeLevel(-1) : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.blueAccent),
            tooltip: 'Help',
            onPressed: () async {
              // <--- Dodaj 'async'

              // 1. PAUZA: Zatrzymujemy czas
              _stopTimer();

              // 2. CZEKAMY: Aplikacja czeka w tej linii, aż zamkniesz okno pomocy
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );

              // 3. START: Wznawiamy czas (funkcja już nie zeruje licznika)
              // Sprawdzamy też, czy gra nie została w międzyczasie wygrana/zakończona
              if (mounted && !board.isEmpty) {
                _startTimer();
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              // NOWE: Szara strzałka jeśli nie odblokowano następnego
              color: canGoNext ? Colors.black : Colors.grey[300],
            ),
            onPressed: canGoNext ? () => _changeLevel(1) : null,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : board.isEmpty
          ? _buildErrorView()
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30.0,
                    left: 20,
                    right: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _history.isNotEmpty ? _undo : null,
                        icon: const Icon(Icons.undo),
                        label: const Text("Undo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _clearBoard,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Clear"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
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

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Error: Missing level data.",
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _loadLevel(currentLevelIndex),
            child: const Text("Try again"),
          ),
        ],
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
