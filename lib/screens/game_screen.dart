import 'dart:async'; // Potrzebne do Timera
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'help_screen.dart'; // Upewnij się, że ten import tu jest

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
  // --- ZMIENNE DO PRZECIĄGANIA (DRAG) ---
  CellState? _dragTargetState; // Jaki stan nakładamy? (np. malujemy same X)
  int _lastDragIndex =
      -1; // Indeks ostatnio dotkniętego pola (żeby nie mrugało)

  int gridSize = 8;
  final bool isDebugging = false;
  String difficulty = 'easy';
  int currentLevelIndex = 1;
  bool isLoading = true;

  int maxUnlockedLevel = 1;

  // --- TIMER ---
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // --- DANE GRY ---
  List<CellModel> board = [];
  List<List<CellModel>> _history = [];

  // --- KOLORY (Zaktualizowane) ---
  final List<Color> zoneColors = [
    Colors.red[100]!,
    Colors.blue[100]!,
    Colors.green[200]!, // Bardziej trawiasty
    Colors.orange[100]!,
    Colors.purple[100]!,
    Colors.cyan[100]!, // Mniej zielony niż Teal
    Colors.yellow[200]!, // Wyraźniejszy żółty
    Colors.brown[100]!,
    Colors.pink[100]!,
    Colors.indigo[100]!, // Zamiast Lime
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
    _stopTimer();
    // Nie zerujemy tutaj czasu, żeby móc wznawiać (np. po wyjściu z pomocy)
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
      _elapsed =
          Duration.zero; // Zerowanie czasu przy ładowaniu nowego/restartowaniu
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

  // --- AKCJE GRACZA ---

  // NOWE: Funkcja restartu
  void _restartLevel() {
    // Po prostu ładujemy ten sam poziom od nowa.
    // To automatycznie wyczyści planszę, historię i zresetuje czas.
    _loadLevel(currentLevelIndex);
  }

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

  // void _handleTap(int index) {
  //   if (isLoading) return;
  //   _saveToHistory();

  //   setState(() {
  //     CellModel cell = board[index];
  //     if (cell.state == CellState.empty) {
  //       cell.state = CellState.cross;
  //     } else if (cell.state == CellState.cross) {
  //       cell.state = CellState.queen;
  //     } else {
  //       cell.state = CellState.empty;
  //     }

  //     _validateBoard();

  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _checkWinCondition();
  //     });
  //   });
  // }

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
          title: const Text("Gratulacje! 🎉"),
          content: Text("Poziom ukończony w czasie: ${_formatTime(_elapsed)}"),
          actions: [
            // Dodano opcję "Zagraj ponownie" w oknie wygranej, żeby poprawić wynik
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartLevel();
              },
              child: const Text("Popraw wynik"),
            ),
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

    if (newLevel > maxUnlockedLevel) return;

    if (newLevel != currentLevelIndex) {
      _loadLevel(newLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Pomoc',
            onPressed: () async {
              _stopTimer();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
              if (mounted && board.isNotEmpty) {
                _startTimer();
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
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
                        // LayoutBuilder daje nam dostęp do wymiarów (constraints)
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              // START GESTU: Resetujemy zmienne i przetwarzamy pierwsze pole
                              onPanStart: (details) {
                                _dragTargetState = null;
                                _lastDragIndex = -1;
                                _processDragInput(
                                  details.localPosition,
                                  constraints.maxWidth,
                                );
                              },
                              // RUCH PALCA: Aktualizujemy kolejne pola
                              onPanUpdate: (details) {
                                _processDragInput(
                                  details.localPosition,
                                  constraints.maxWidth,
                                );
                              },
                              // KONIEC GESTU: Zapisujemy historię (dla przycisku Cofnij)
                              onPanEnd: (details) {
                                _saveToHistory();
                                _dragTargetState = null;
                                _lastDragIndex = -1;
                              },

                              child: GridView.builder(
                                // Wyłączamy przewijanie GridView, żeby nie kłóciło się z naszym gestem
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: gridSize,
                                      crossAxisSpacing: 0,
                                      mainAxisSpacing: 0,
                                    ),
                                itemCount: board.length,
                                itemBuilder: (context, index) {
                                  if (index >= board.length)
                                    return const SizedBox();
                                  return _buildCell(board[index], index);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // --- PASEK NARZĘDZI (Zaktualizowany) ---
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30.0,
                    left: 10,
                    right: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.undo,
                        label: "Undo",
                        color: Colors.grey[200]!,
                        textColor: Colors.black,
                        onPressed: _history.isNotEmpty ? _undo : null,
                      ),
                      _buildActionButton(
                        icon: Icons.delete_outline,
                        label: "Clear",
                        color: Colors.red[50]!,
                        textColor: Colors.red,
                        onPressed: _clearBoard,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Pomocniczy widget, żeby kod był czystszy (DRY principle)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
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
    );
  }

  Widget _buildCell(CellModel cell, int index) {
    Color cellColor = zoneColors[cell.zoneId % zoneColors.length];

    if (isDebugging && cell.isSolution) {
      cellColor = HSLColor.fromColor(cellColor).withLightness(0.6).toColor();
    }

    // USUNIĘTO: GestureDetector (teraz obsługa jest w głównym Gridzie)
    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        border: cell.hasError
            ? Border.all(color: Colors.red, width: 3)
            : Border.all(color: Colors.black, width: 0.5),
      ),
      child: Center(child: _buildIcon(cell)),
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

  // --- WALIDACJA ---
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

  void _processDragInput(Offset localPosition, double boardPixelSize) {
    // 1. Obliczamy szerokość jednego kafelka w pikselach
    double cellSize = boardPixelSize / gridSize;

    // 2. Obliczamy, w który wiersz i kolumnę trafił palec
    int col = (localPosition.dx / cellSize).floor();
    int row = (localPosition.dy / cellSize).floor();

    // 3. Zabezpieczenie przed wyjściem poza planszę
    if (col < 0 || col >= gridSize || row < 0 || row >= gridSize) return;

    // 4. Zamieniamy na indeks w liście (0..63)
    int index = row * gridSize + col;

    // 5. Optymalizacja: Jeśli wciąż jesteśmy nad tym samym polem, nic nie rób
    if (index == _lastDragIndex) return;
    _lastDragIndex = index;

    // 6. Aplikujemy zmianę
    setState(() {
      CellModel cell = board[index];

      // Jeśli to początek gestu (_dragTargetState jest null), ustalamy co malujemy
      // na podstawie pierwszego dotkniętego pola (cykl: Empty->Cross->Queen->Empty)
      if (_dragTargetState == null) {
        if (cell.state == CellState.empty) {
          _dragTargetState = CellState.cross;
        } else if (cell.state == CellState.cross) {
          _dragTargetState = CellState.queen;
        } else {
          _dragTargetState = CellState.empty;
        }
      }

      // Przypisujemy ustalony stan do obecnego pola
      cell.state = _dragTargetState!;

      _validateBoard();

      // Sprawdzamy wygraną (po klatce, żeby nie zacinało animacji)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkWinCondition();
      });
    });
  }
}
