from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPORT = Path(__file__).resolve().parents[1] / "tools" / "fps-report.py"
PRESENTS = (
    "2026-11-26T10:00:00Z INFO frame presented frame=1",
    "2026-11-26T10:00:01Z INFO frame presented frame=2",
)


class FPSReportTests(unittest.TestCase):
    def run_report(self, *lines):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "run.log"
            log.write_text("\n".join(lines) + "\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(REPORT), str(log)],
                capture_output=True, text=True, timeout=10,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_frame_counter_does_not_advance(self):
        report = self.run_report(PRESENTS[0], PRESENTS[1].replace("frame=2", "frame=1"))

        self.assertRegex(report, r"mean fps \(frames / wall\)\s+0\.00")
        self.assertNotIn("mean frame period implied", report)

    def test_waits_without_elapsed_time(self):
        sample = "2026-11-26T10:00:02Z INFO frame waits: 8, 3 of them ended at once"
        for samples in [(sample,), (sample, sample)]:
            with self.subTest(sample_count=len(samples)):
                report = self.run_report(*PRESENTS, *samples)

                self.assertIn("frame waits (engine counter", report)
                self.assertNotIn("waits over", report)

    def test_wait_rate_covers_only_measured_intervals(self):
        report = self.run_report(
            *PRESENTS,
            "2026-11-26T10:00:02Z INFO frame waits: 99, 1 of them ended at once",
            "2026-11-26T10:00:03Z INFO frame waits: 10, 2 of them ended at once",
            "2026-11-26T10:00:05Z INFO frame waits: 20, 4 of them ended at once",
        )

        self.assertIn("30 waits over 3.0 s = 10.0 waits/s", report)
        self.assertRegex(report, r"mean frame period implied\s+1000\.0 ms")

    def test_refresh_cost_with_no_refreshes(self):
        report = self.run_report(
            *PRESENTS,
            "2026-11-26T10:00:02Z INFO copies per frame: 1.0 submissions; "
            "0 refreshes 0.0 MB, moves 0.00 ms; preparing: 0.0 ms",
        )

        self.assertIn("mean over 1 samples: 0.0 MB/frame, 0.00 ms/frame", report)
        self.assertNotIn("per engine refresh:", report)

    def test_refresh_cost_with_refreshes(self):
        report = self.run_report(
            *PRESENTS,
            "2026-11-26T10:00:02Z INFO copies per frame: 1.0 submissions; "
            "12 refreshes 6.0 MB, moves 3.00 ms; preparing: 0.0 ms",
        )

        self.assertIn("per engine refresh: 0.25 ms (3.00 ms/frame / 12.0 refreshes/frame), 0.5 MB", report)
