from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPORT = Path(__file__).resolve().parents[1] / "tools" / "fps-report.py"


class FPSCompareTests(unittest.TestCase):
    def test_black_frames_count_transitions_not_diagnostic_lines(self):
        first_transition = (
            "2026-11-26T10:00:00Z WARN victory_gpu::queue: "
            "a black frame after a frame that was not frame=16 black_frames=1"
        )
        messages = (
            first_transition,
            "2026-11-26T10:00:00Z WARN victory_gpu::queue: black frame 16: draw A",
            "2026-11-26T10:00:00Z WARN victory_gpu::queue: black frame 16: draw B",
            "2026-11-26T10:00:01Z WARN victory_gpu::queue: levels after the black frame frame=22",
        )
        another_transition = (
            "2026-11-26T10:00:02Z WARN victory_gpu::queue: "
            "a black frame after a frame that was not frame=32 black_frames=2"
        )
        with tempfile.TemporaryDirectory() as directory:
            baseline = Path(directory) / "baseline.log"
            same = Path(directory) / "same.log"
            worse = Path(directory) / "worse.log"
            baseline.write_text(first_transition + "\n", encoding="utf-8")
            same.write_text("\n".join(messages) + "\n", encoding="utf-8")
            worse.write_text("\n".join((*messages, another_transition)) + "\n", encoding="utf-8")
            report = subprocess.run(
                [sys.executable, str(REPORT), "--compare", str(baseline), str(same), str(worse)],
                check=True, capture_output=True, text=True, timeout=10,
            ).stdout

        rows = [
            line.split()[2:]
            for line in report.splitlines()
            if line.lstrip().startswith("black frames ")
        ]
        self.assertEqual(rows, [["1", "1", "same"], ["1", "2", "+100%"]])
