import os
import json
import random
import logging


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(message)s', datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)


class LevelGenerator:
    def __init__(self, size=8):
        self.size = size
        self.solver = LevelSolver(size)

    def generate_puzzle(self):
        # 1. Queens
        solution_queens = self._generate_solution_placement()
        if not solution_queens: return None
        # 2. Zones (Chaotic works best for 8x8)
        zones = self._grow_zones_chaotic(solution_queens)
        if not zones: return None
        # 3. Uniqueness
        self.solver.set_zones(zones)
        if self.solver.count_solutions(limit=2) != 1: return None

        return {
            "size": self.size,
            "difficulty": "easy",
            "zones": zones,
            "solution_queens": [{"row": r, "col": c} for r, c in solution_queens]
        }

    def _generate_solution_placement(self):
        queens = []
        cols = list(range(self.size))
        def place_queen(row):
            if row == self.size: return True
            random.shuffle(cols)
            for col in cols:
                if any(q[1] == col for q in queens): continue
                if any(abs(q[0]-row)<=1 and abs(q[1]-col)<=1 for q in queens): continue
                queens.append((row, col))
                if place_queen(row+1): return True
                queens.pop()
            return False
        if place_queen(0): return sorted(queens)
        return []

    def _grow_zones_chaotic(self, queens):
        zones = [[-1]*self.size for _ in range(self.size)]
        queue = []
        for i, (r, c) in enumerate(queens):
            zones[r][c] = i
            for dr, dc in [(0,1),(0,-1),(1,0),(-1,0)]:
                if 0<=r+dr<self.size and 0<=c+dc<self.size: queue.append((r+dr, c+dc, i))
        
        random.shuffle(queue)
        while queue:
            idx = random.randint(0, len(queue)-1)
            r, c, zid = queue.pop(idx)
            if zones[r][c] == -1:
                zones[r][c] = zid
                for dr, dc in [(0,1),(0,-1),(1,0),(-1,0)]:
                    if 0<=r+dr<self.size and 0<=c+dc<self.size and zones[r+dr][c+dc]==-1:
                        queue.append((r+dr, c+dc, zid))
        
        if any(-1 in row for row in zones): return None
        return zones


class LevelSolver:
    def __init__(self, size):
        self.size = size
        self.zones = []
        self.queens = []
        self.count = 0

    def set_zones(self, zones):
        self.zones = zones

    def count_solutions(self, limit=2):
        self.count = 0
        self.queens = []
        self._solve(0, limit)
        return self.count

    def _is_safe(self, r, c):
        for qr, qc in self.queens:
            if qc == c: return False
            if self.zones[qr][qc] == self.zones[r][c]: return False
            if abs(qr - r) <= 1 and abs(qc - c) <= 1: return False
        return True

    def _solve(self, r, limit):
        if self.count >= limit: return
        if r == self.size:
            self.count += 1
            return
        for c in range(self.size):
            if self._is_safe(r, c):
                self.queens.append((r, c))
                self._solve(r+1, limit)
                self.queens.pop()
                if self.count >= limit: return


def main():
    folder = "./assets/levels/easy/"
    if not os.path.exists(folder): os.makedirs(folder)
    
    gen = LevelGenerator(8)
    count = 0
    print("Generating 50 Easy Levels...")
    
    while count < 50:
        p = gen.generate_puzzle()
        if p:
            count += 1
            with open(os.path.join(folder, f"level_{count}.json"), 'w') as f:
                json.dump(p, f)
            print(f"Generated Level {count}/50")

if __name__ == "__main__":
    main()