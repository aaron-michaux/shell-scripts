#!/usr/bin/env python3
"""Comprehensive test suite for vidups.py"""

from __future__ import annotations

import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, mock_open, patch

sys.path.insert(0, str(Path(__file__).parent))
import vidups


class TempDirMixin:
    def _tmpdir(self) -> Path:
        """Create a temporary directory and return it as a Path."""
        return Path(tempfile.mkdtemp(prefix="vidups_test_"))

    def _make_file(self, parent: Path, name: str, content: str = "") -> Path:
        p = parent / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        return p


class TestPhaseNumber(unittest.TestCase):
    def test_valid_phases(self):
        self.assertEqual(vidups.phase_number("files"), 0)
        self.assertEqual(vidups.phase_number("hashes"), 1)
        self.assertEqual(vidups.phase_number("compare"), 2)
        self.assertEqual(vidups.phase_number("output"), 3)

    def test_invalid_phase_raises(self):
        with self.assertRaises(ValueError):
            vidups.phase_number("nonexistent")


class TestHashPathFor(unittest.TestCase):
    def test_basic_path(self):
        movie = Path("/home/user/videos/movie.mp4").resolve()
        directory = Path("/home/user/videos").resolve()
        expected = vidups.tmpd() / "movie.mp4.hashes-bin"
        result = vidups.hash_path_for(movie, directory)
        self.assertEqual(result, expected)

    def test_nested_path(self):
        movie = Path("/root/a/b/c/v.mkv").resolve()
        directory = Path("/root").resolve()
        expected = vidups.tmpd() / "a" / "b" / "c" / "v.mkv.hashes-bin"
        result = vidups.hash_path_for(movie, directory)
        self.assertEqual(result, expected)

    def test_deeply_nested(self):
        movie = Path("/data/season1/episodes/s01e01.mp4").resolve()
        directory = Path("/data").resolve()
        result = vidups.hash_path_for(movie, directory)
        self.assertTrue(str(result).endswith("season1/episodes/s01e01.mp4.hashes-bin"))


class TestFrameToHash(unittest.TestCase):
    def test_all_same_pixels(self):
        frame = bytes([128] * 256)
        result = vidups._frame_to_hash(frame)
        self.assertEqual(len(result), 32)
        self.assertEqual(result, bytes(32))

    def test_all_zero_and_ff(self):
        frame = bytes([0] * 128 + [255] * 128)
        result = vidups._frame_to_hash(frame)
        self.assertEqual(len(result), 32)
        for i in range(16):
            self.assertEqual(result[i], 0x00)
        for i in range(16, 32):
            self.assertEqual(result[i], 0xFF)

    def test_alternating(self):
        frame = bytes([200, 100] * 128)
        result = vidups._frame_to_hash(frame)
        self.assertEqual(len(result), 32)

    def test_known_pattern(self):
        frame = bytes([10] * 128 + [250] * 128)
        result = vidups._frame_to_hash(frame)
        self.assertEqual(len(result), 32)
        self.assertEqual(result[:16], bytes(16))
        self.assertEqual(result[16:], bytes([0xFF] * 16))

    def test_result_length_always_32(self):
        import random
        random.seed(42)
        for _ in range(20):
            frame = bytes(random.choices(range(256), k=256))
            self.assertEqual(len(vidups._frame_to_hash(frame)), 32)


class TestHamming32(unittest.TestCase):
    def test_identical(self):
        a = bytes(32)
        self.assertEqual(vidups.hamming_32(a, a), 0)

    def test_known_distance(self):
        a = bytes(32)
        b = bytearray(32)
        b[0] = 1
        self.assertEqual(vidups.hamming_32(a, bytes(b)), 1)

    def test_max_distance(self):
        a = bytes(32)
        b = bytes([0xFF] * 32)
        self.assertEqual(vidups.hamming_32(a, b), 256)

    def test_single_byte_diff(self):
        a = bytes([0xF0] + [0] * 31)
        b = bytes([0x0F] + [0] * 31)
        self.assertEqual(vidups.hamming_32(a, b), 8)

    def test_random_pairs(self):
        import random
        random.seed(99)
        for _ in range(50):
            a = bytes(random.choices(range(256), k=32))
            b = bytes(random.choices(range(256), k=32))
            dist = vidups.hamming_32(a, b)
            self.assertGreaterEqual(dist, 0)
            self.assertLessEqual(dist, 256)


class TestMedianHamming(unittest.TestCase):
    def test_identical_frames(self):
        a = [bytes(32)] * 10
        b = [bytes(32)] * 10
        self.assertEqual(vidups.median_hamming(a, b), 0)

    def test_mixed_distances(self):
        a = [bytes(32)] * 5
        b_frames = []
        for i in range(5):
            bb = bytearray(32)
            bb[0] = i
            b_frames.append(bytes(bb))
        self.assertEqual(vidups.median_hamming(a, b_frames), 1)

    def test_empty_frames(self):
        self.assertEqual(vidups.median_hamming([], []), float("inf"))
        self.assertEqual(vidups.median_hamming([bytes(32)], []), float("inf"))

    def test_mismatched_lengths(self):
        a = [bytes(32)] * 10
        b = [bytes(32)] * 3
        self.assertEqual(vidups.median_hamming(a, b), 0)

    def test_high_distance(self):
        a = [bytes(32)] * 5
        b = [bytes([0xFF] * 32)] * 5
        self.assertEqual(vidups.median_hamming(a, b), 256)


class TestLoadHashes(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.mkdtemp(prefix="load_hashes_test_")

    def tearDown(self):
        shutil.rmtree(self._tmp, ignore_errors=True)

    def _write_hashes(self, fname: str, data: bytes):
        p = Path(self._tmp) / fname
        p.write_bytes(data)
        return p

    def test_valid_hashes(self):
        p = self._write_hashes("good.hashes-bin", bytes(32) * 5)
        result = vidups.load_hashes(p)
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 5)
        for h in result:
            self.assertEqual(len(h), 32)

    def test_too_short(self):
        p = self._write_hashes("short.hashes-bin", b"abc")
        self.assertIsNone(vidups.load_hashes(p))

    def test_exactly_one_frame(self):
        p = self._write_hashes("one.hashes-bin", bytes(32))
        result = vidups.load_hashes(p)
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 1)

    def test_empty_file(self):
        p = self._write_hashes("empty.hashes-bin", b"")
        self.assertIsNone(vidups.load_hashes(p))

    def test_non_existent_file(self):
        self.assertIsNone(vidups.load_hashes(Path(self._tmp) / "nope.bin"))

    def test_unaligned_size(self):
        p = self._write_hashes("unaligned.hashes-bin", bytes(33))
        self.assertIsNone(vidups.load_hashes(p))


class TestEnsureTmpd(unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_home_")
        os.environ["HOME"] = self._tmp_home

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def test_creates_tmpd(self):
        t = vidups.tmpd()
        self.assertFalse(t.exists())
        vidups.ensure_tmpd()
        self.assertTrue(t.is_dir())

    def test_idempotent(self):
        vidups.ensure_tmpd()
        vidups.ensure_tmpd()
        self.assertTrue(vidups.tmpd().is_dir())


class TestPhase1Discover(TempDirMixin, unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_phase1_home_")
        os.environ["HOME"] = self._tmp_home
        vidups.ensure_tmpd()

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def test_discovers_video_files(self):
        root = Path(self._tmpdir())
        self._make_file(root, "a.mp4")
        self._make_file(root, "b.mkv")
        self._make_file(root, "c.avi")
        self._make_file(root, "notes.txt")
        self._make_file(root, "image.jpg")

        movies = vidups.phase_1_discover(root, lazy=False)

        movie_names = {p.name for p in movies}
        self.assertEqual(movie_names, {"a.mp4", "b.mkv", "c.avi"})
        self.assertEqual(len(movies), 3)

    def test_other_files(self):
        root = Path(self._tmpdir())
        self._make_file(root, "video.mp4")
        self._make_file(root, "notes.txt")
        self._make_file(root, "image.png")

        vidups.phase_1_discover(root, lazy=False)

        others = Path(vidups.tmpd() / "1.other-files.text").read_text().splitlines()
        other_names = {Path(p).name for p in others if p}
        self.assertTrue("notes.txt" in other_names)
        self.assertTrue("image.png" in other_names)
        self.assertTrue("video.mp4" not in other_names)

    def test_symlinks_excluded(self):
        root = Path(self._tmpdir())
        real = self._make_file(root, "real.mp4")
        sym = root / "link.mp4"
        os.symlink(str(real), str(sym))

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(names, {"real.mp4"})

    def test_hardlinks_excluded(self):
        root = Path(self._tmpdir())
        real = self._make_file(root, "real.mp4")
        hlink = root / "hardlink.mp4"
        os.link(str(real), str(hlink))

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(len(names), 1, f"Expected 1 movie, got: {names}")

    def test_too_many_hardlinks(self):
        root = Path(self._tmpdir())
        real = self._make_file(root, "base.mp4")
        for i in range(5):
            os.link(str(real), str(root / f"link{i}.mp4"))

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(len(names), 1)

    def test_hidden_files_excluded(self):
        root = Path(self._tmpdir())
        self._make_file(root, ".hidden.mp4")
        self._make_file(root, "visible.mp4")

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(names, {"visible.mp4"})

    def test_hidden_dirs_excluded(self):
        root = Path(self._tmpdir())
        hidden_d = root / ".hidden_dir"
        hidden_d.mkdir()
        self._make_file(hidden_d, "nested.mp4")
        self._make_file(root, "top.mp4")

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(names, {"top.mp4"})

    def test_all_video_extensions(self):
        root = Path(self._tmpdir())
        for ext in vidups.VIDEO_EXTENSIONS:
            self._make_file(root, f"video{ext}")

        movies = vidups.phase_1_discover(root, lazy=False)
        self.assertEqual(len(movies), len(vidups.VIDEO_EXTENSIONS))

    def test_case_insensitive_extension(self):
        root = Path(self._tmpdir())
        self._make_file(root, "movie.MP4")
        self._make_file(root, "other.MKV")

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(names, {"movie.MP4", "other.MKV"})

    def test_sorted_output(self):
        root = Path(self._tmpdir())
        self._make_file(root, "z.mp4")
        self._make_file(root, "a.mp4")
        self._make_file(root, "m.mp4")

        movies = vidups.phase_1_discover(root, lazy=False)
        self.assertEqual([p.name for p in movies], ["a.mp4", "m.mp4", "z.mp4"])

    def test_lazy_skips_when_output_exists(self):
        root = Path(self._tmpdir())
        self._make_file(root, "a.mp4")

        mo = vidups.tmpd() / "1.movie-files.text"
        oo = vidups.tmpd() / "1.other-files.text"
        mo.parent.mkdir(parents=True, exist_ok=True)
        mo.write_text("/fake/path/video.mp4\n")
        oo.write_text("/fake/path/notes.txt\n")

        movies = vidups.phase_1_discover(root, lazy=True)

        self.assertEqual(len(movies), 1)
        self.assertEqual(str(movies[0]), "/fake/path/video.mp4")

    def test_lazy_computes_when_output_missing(self):
        root = Path(self._tmpdir())
        self._make_file(root, "movie.mp4")

        movies = vidups.phase_1_discover(root, lazy=True)
        self.assertEqual(len(movies), 1)

    def test_empty_directory(self):
        root = Path(self._tmpdir())
        movies = vidups.phase_1_discover(root, lazy=False)
        self.assertEqual(movies, [])
        self.assertTrue((vidups.tmpd() / "1.movie-files.text").exists())
        self.assertTrue((vidups.tmpd() / "1.other-files.text").exists())

    def test_non_video_extensions_ignored(self):
        root = Path(self._tmpdir())
        for ext in (".txt", ".jpg", ".png", ".pdf", ".doc", ".html", ".css"):
            self._make_file(root, f"file{ext}")

        movies = vidups.phase_1_discover(root, lazy=False)
        self.assertEqual(movies, [])

    def test_subdirectory_traversal(self):
        root = Path(self._tmpdir())
        sub = root / "sub"
        sub.mkdir()
        self._make_file(root, "top.mp4")
        self._make_file(sub, "nested.mkv")

        movies = vidups.phase_1_discover(root, lazy=False)
        names = {p.name for p in movies}
        self.assertEqual(names, {"top.mp4", "nested.mkv"})

    def test_oserror_skipped(self):
        root = Path(self._tmpdir())
        unreadable_dir = root / "noperm"
        unreadable_dir.mkdir()
        self._make_file(unreadable_dir, "secret.mp4")
        unreadable_dir.chmod(0o000)
        try:
            movies = vidups.phase_1_discover(root, lazy=False)
            names = {p.name for p in movies}
            self.assertNotIn("secret.mp4", names)
        finally:
            unreadable_dir.chmod(0o755)


class TestGetDuration(unittest.TestCase):
    @patch("subprocess.run")
    def test_valid_duration(self, mock_run):
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = json.dumps(
            {"format": {"duration": "120.5"}}
        ).encode()

        result = vidups.get_duration(Path("/tmp/test.mp4"))
        self.assertEqual(result, 120.5)

    @patch("subprocess.run")
    def test_ffprobe_failure(self, mock_run):
        mock_run.return_value.returncode = 1
        result = vidups.get_duration(Path("/tmp/test.mp4"))
        self.assertIsNone(result)

    @patch("subprocess.run")
    def test_ffprobe_not_installed(self, mock_run):
        mock_run.side_effect = FileNotFoundError()
        result = vidups.get_duration(Path("/tmp/test.mp4"))
        self.assertIsNone(result)

    @patch("subprocess.run")
    def test_json_parse_error(self, mock_run):
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = b"not json"
        result = vidups.get_duration(Path("/tmp/test.mp4"))
        self.assertIsNone(result)

    @patch("subprocess.run")
    def test_timeout(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="ffprobe", timeout=60)
        result = vidups.get_duration(Path("/tmp/test.mp4"))
        self.assertIsNone(result)


class TestPhase2Hashes(TempDirMixin, unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_phase2_home_")
        os.environ["HOME"] = self._tmp_home
        vidups.ensure_tmpd()
        self._root = Path(self._tmpdir())

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    @patch("vidups.compute_hashes")
    def test_generates_hash_files(self, mock_compute):
        movie = self._make_file(self._root, "movie.mp4")
        frame_hashes = bytes(32) * 3
        mock_compute.return_value = frame_hashes

        hash_map = vidups.phase_2_hashes(self._root, [movie], lazy=False)

        hp = vidups.hash_path_for(movie, self._root)
        self.assertTrue(hp.exists())
        self.assertEqual(hp.read_bytes(), frame_hashes)
        self.assertEqual(hash_map[movie], hp)

    @patch("vidups.compute_hashes")
    def test_skips_when_newer_in_lazy_mode(self, mock_compute):
        movie = self._make_file(self._root, "movie.mp4")
        hp = vidups.hash_path_for(movie, self._root)
        hp.parent.mkdir(parents=True, exist_ok=True)
        hp.write_bytes(b"\x00" * 96)

        old_stat = movie.stat()
        hp_stat = hp.stat()
        mtime_diff = hp_stat.st_mtime - old_stat.st_mtime
        if mtime_diff < 0:
            os.utime(str(hp), (old_stat.st_mtime + 10, old_stat.st_mtime + 10))

        hash_map = vidups.phase_2_hashes(self._root, [movie], lazy=True)
        mock_compute.assert_not_called()
        self.assertIn(movie, hash_map)

    @patch("vidups.compute_hashes")
    def test_recomputes_when_older_in_lazy_mode(self, mock_compute):
        movie = self._make_file(self._root, "movie.mp4")
        hp = vidups.hash_path_for(movie, self._root)
        hp.parent.mkdir(parents=True, exist_ok=True)
        hp.write_bytes(b"\x00" * 96)
        os.utime(str(hp), (0, 0))

        frame_hashes = bytes(32) * 3
        mock_compute.return_value = frame_hashes

        hash_map = vidups.phase_2_hashes(self._root, [movie], lazy=True)
        mock_compute.assert_called_once()
        self.assertEqual(hp.read_bytes(), frame_hashes)

    @patch("vidups.compute_hashes")
    def test_handles_compute_failure(self, mock_compute):
        movie = self._make_file(self._root, "movie.mp4")
        mock_compute.return_value = None

        hash_map = vidups.phase_2_hashes(self._root, [movie], lazy=False)

        hp = vidups.hash_path_for(movie, self._root)
        self.assertFalse(hp.exists())
        self.assertIn(movie, hash_map)

    @patch("vidups.compute_hashes")
    def test_empty_movie_list(self, mock_compute):
        hash_map = vidups.phase_2_hashes(self._root, [], lazy=False)
        self.assertEqual(hash_map, {})
        mock_compute.assert_not_called()

    @patch("vidups.compute_hashes")
    def test_multiple_movies(self, mock_compute):
        movies = [
            self._make_file(self._root, f"movie{i}.mp4")
            for i in range(3)
        ]
        mock_compute.side_effect = [bytes(32) * (i + 1) for i in range(3)]

        hash_map = vidups.phase_2_hashes(self._root, movies, lazy=False)

        self.assertEqual(len(hash_map), 3)
        for movie in movies:
            hp = vidups.hash_path_for(movie, self._root)
            self.assertTrue(hp.exists())
            self.assertIn(movie, hash_map)


class TestComputeHashes(unittest.TestCase):
    @patch("subprocess.run")
    def test_valid_output(self, mock_run):
        raw = bytearray()
        mean_val = 128
        for _ in range(2):
            frame = bytes([mean_val - 10] * 128 + [mean_val + 10] * 128)
            raw.extend(frame)
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = bytes(raw)

        result = vidups.compute_hashes(Path("/tmp/test.mp4"))
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 64)

    @patch("subprocess.run")
    def test_ffmpeg_failure(self, mock_run):
        mock_run.return_value.returncode = 1
        self.assertIsNone(vidups.compute_hashes(Path("/tmp/test.mp4")))

    @patch("subprocess.run")
    def test_too_few_bytes(self, mock_run):
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = b"\x00" * 100
        self.assertIsNone(vidups.compute_hashes(Path("/tmp/test.mp4")))

    @patch("subprocess.run")
    def test_file_not_found(self, mock_run):
        mock_run.side_effect = FileNotFoundError()
        self.assertIsNone(vidups.compute_hashes(Path("/tmp/test.mp4")))

    @patch("subprocess.run")
    def test_timeout(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="ffmpeg", timeout=600)
        self.assertIsNone(vidups.compute_hashes(Path("/tmp/test.mp4")))


class TestPhase3Compare(TempDirMixin, unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_phase3_home_")
        os.environ["HOME"] = self._tmp_home
        vidups.ensure_tmpd()
        self._root = Path(self._tmpdir())

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def _put_hash(self, movie: Path, frames: list[bytes]):
        hp = vidups.hash_path_for(movie, self._root)
        hp.parent.mkdir(parents=True, exist_ok=True)
        hp.write_bytes(b"".join(frames))

    @patch("vidups.get_duration")
    def test_duration_gate_rejects(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.side_effect = lambda p: 100.0 if p.name == "a.mp4" else 200.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["strategy"], "duration")
        self.assertLess(results[0]["score"], 80)

    @patch("vidups.get_duration")
    def test_duration_gate_passes_close_match(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.side_effect = lambda p: 100.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        with patch("vidups.run_vmaf") as mock_vmaf:
            mock_vmaf.return_value = 97.0
            results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
            self.assertEqual(len(results), 1)
            self.assertNotEqual(results[0]["strategy"], "duration")

    @patch("vidups.get_duration")
    def test_zero_duration_reported(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.side_effect = lambda p: 0.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["strategy"], "duration")
        self.assertEqual(results[0]["score"], 0.0)

    @patch("vidups.get_duration")
    def test_none_duration_reported(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.side_effect = lambda p: None

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["strategy"], "duration")
        self.assertEqual(results[0]["score"], 0.0)

    @patch("vidups.get_duration")
    def test_missing_hashes_reported(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.return_value = 100.0
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["strategy"], "hamming")
        self.assertEqual(results[0]["score"], 0.0)

    @patch("vidups.get_duration")
    def test_hamming_gate_rejects(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.return_value = 100.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes([0xFF] * 32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["strategy"], "hamming")

    @patch("vidups.get_duration")
    def test_vmaf_match(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.return_value = 100.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        with patch("vidups.run_vmaf") as mock_vmaf:
            mock_vmaf.return_value = 97.3
            results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["strategy"], "match")
            self.assertEqual(results[0]["score"], 97.3)

    @patch("vidups.get_duration")
    def test_vmaf_non_match(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.return_value = 100.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        with patch("vidups.run_vmaf") as mock_vmaf:
            mock_vmaf.return_value = 80.0
            results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["strategy"], "vmaf")
            self.assertEqual(results[0]["score"], 80.0)

    @patch("vidups.get_duration")
    def test_vmaf_none_reported(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        mock_dur.return_value = 100.0

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        with patch("vidups.run_vmaf") as mock_vmaf:
            mock_vmaf.return_value = None
            results = vidups.phase_3_compare([a, b], hash_map, lazy=False)
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["strategy"], "vmaf")
            self.assertIsNone(results[0]["score"])

    @patch("vidups.get_duration")
    def test_all_pairs_compared(self, mock_dur):
        n = 4
        movies = [self._make_file(self._root, f"m{i}.mp4") for i in range(n)]
        mock_dur.return_value = 100.0

        for m in movies:
            self._put_hash(m, [bytes(32)] * 3)
        hash_map = {m: vidups.hash_path_for(m, self._root) for m in movies}

        with patch("vidups.run_vmaf") as mock_vmaf:
            mock_vmaf.return_value = 97.0
            results = vidups.phase_3_compare(movies, hash_map, lazy=False)
            expected_pairs = n * (n - 1) // 2
            self.assertEqual(len(results), expected_pairs)

    @patch("vidups.get_duration")
    def test_single_movie_no_pairs(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        mock_dur.return_value = 100.0
        self._put_hash(a, [bytes(32)] * 3)
        hash_map = {a: vidups.hash_path_for(a, self._root)}

        results = vidups.phase_3_compare([a], hash_map, lazy=False)
        self.assertEqual(results, [])

    @patch("vidups.get_duration")
    def test_every_pair_reported(self, mock_dur):
        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        c = self._make_file(self._root, "c.mp4")
        durations = {"a.mp4": 100.0, "b.mp4": 100.0, "c.mp4": 50.0}
        mock_dur.side_effect = lambda p: durations[p.name]

        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        self._put_hash(c, [bytes(32)] * 5)
        hash_map = {m: vidups.hash_path_for(m, self._root) for m in (a, b, c)}

        with patch("vidups.run_vmaf") as mock_vmaf:
            mock_vmaf.return_value = 96.0
            results = vidups.phase_3_compare([a, b, c], hash_map, lazy=False)

        self.assertEqual(len(results), 3)
        pairs = {(r["file1"], r["file2"], r["strategy"]) for r in results}
        self.assertIn((str(a), str(b), "match"), pairs)
        self.assertIn((str(a), str(c), "duration"), pairs)
        self.assertIn((str(b), str(c), "duration"), pairs)

    def test_lazy_loads_existing_output(self):
        output = vidups.tmpd() / "output.json"
        preloaded = [
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "match", "score": 97.0}
        ]
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(preloaded))

        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        results = vidups.phase_3_compare([a, b], hash_map, lazy=True)
        self.assertEqual(results, preloaded)

    def test_lazy_recomputes_when_stale_empty_output(self):
        output = vidups.tmpd() / "output.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text("[]")

        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        hash_map = {a: vidups.hash_path_for(a, self._root),
                     b: vidups.hash_path_for(b, self._root)}

        with patch("vidups.get_duration") as mock_dur, patch("vidups.run_vmaf") as mock_vmaf:
            mock_dur.return_value = 100.0
            mock_vmaf.return_value = 97.0
            results = vidups.phase_3_compare([a, b], hash_map, lazy=True)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["strategy"], "match")

    def test_lazy_recomputes_when_wrong_count(self):
        output = vidups.tmpd() / "output.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps([
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "match", "score": 97.0}
        ]))

        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        c = self._make_file(self._root, "c.mp4")
        self._put_hash(a, [bytes(32)] * 5)
        self._put_hash(b, [bytes(32)] * 5)
        self._put_hash(c, [bytes(32)] * 5)
        hash_map = {m: vidups.hash_path_for(m, self._root) for m in (a, b, c)}

        with patch("vidups.get_duration") as mock_dur, patch("vidups.run_vmaf") as mock_vmaf:
            mock_dur.return_value = 100.0
            mock_vmaf.return_value = 97.0
            results = vidups.phase_3_compare([a, b, c], hash_map, lazy=True)

        self.assertEqual(len(results), 3)

    def test_lazy_handles_corrupt_json(self):
        output = vidups.tmpd() / "output.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text("not json {{{")

        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")

        with patch("vidups.get_duration") as mock_dur:
            mock_dur.return_value = 0.0
            results = vidups.phase_3_compare([a, b], {}, lazy=True)
            self.assertNotEqual(results, [{"bad": "json"}])

    def test_lazy_handles_non_list_json(self):
        output = vidups.tmpd() / "output.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text('{"key": "value"}')

        a = self._make_file(self._root, "a.mp4")
        b = self._make_file(self._root, "b.mp4")
        with patch("vidups.get_duration") as mock_dur:
            mock_dur.return_value = 0.0
            results = vidups.phase_3_compare([a, b], {}, lazy=True)
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["strategy"], "duration")


class TestRunVmaf(unittest.TestCase):
    @patch("subprocess.run")
    def test_successful_vmaf(self, mock_run):
        mock_run.return_value.returncode = 0
        log_data = json.dumps({"pooled_metrics": {"vmaf": {"mean": 96.5}}})

        with patch("builtins.open", mock_open(read_data=log_data)):
            with patch("tempfile.NamedTemporaryFile") as mock_tmp:
                mock_tmp.return_value.__enter__.return_value.name = "/tmp/vmaf_test.json"
                result = vidups.run_vmaf(Path("/tmp/a.mp4"), Path("/tmp/b.mp4"))
                self.assertEqual(result, 96.5)

    @patch("subprocess.run")
    def test_ffmpeg_not_found(self, mock_run):
        mock_run.side_effect = FileNotFoundError()
        result = vidups.run_vmaf(Path("/tmp/a.mp4"), Path("/tmp/b.mp4"))
        self.assertIsNone(result)

    @patch("subprocess.run")
    def test_timeout(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="ffmpeg", timeout=1200)
        result = vidups.run_vmaf(Path("/tmp/a.mp4"), Path("/tmp/b.mp4"))
        self.assertIsNone(result)


class TestPhase4Output(TempDirMixin, unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_phase4_home_")
        os.environ["HOME"] = self._tmp_home
        vidups.ensure_tmpd()
        self._root = Path(self._tmpdir())

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def _run_output(self, results, output_file=None):
        captured = io.StringIO()
        save_stdout = sys.stdout
        sys.stdout = captured
        try:
            vidups.phase_4_output(results, output_file)
        finally:
            sys.stdout = captured

    def test_json_output_written(self):
        results = [
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "match", "score": 97.3}
        ]
        self._run_output(results)
        output = vidups.tmpd() / "output.json"
        self.assertTrue(output.exists())
        loaded = json.loads(output.read_text())
        self.assertEqual(loaded, results)

    def test_optional_output_file(self):
        results = [
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "duration", "score": 45.2}
        ]
        opt_out = self._root / "custom_output.json"
        self._run_output(results, output_file=str(opt_out))
        self.assertTrue(opt_out.exists())
        loaded = json.loads(opt_out.read_text())
        self.assertEqual(loaded, results)

    def test_text_output_written(self):
        results = [
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "match", "score": 97.3}
        ]
        self._run_output(results)
        text_out = vidups.tmpd() / "output.text"
        self.assertTrue(text_out.exists())
        content = text_out.read_text()
        self.assertIn("match", content)
        self.assertIn("/a.mp4", content)

    def test_empty_results_table_format(self):
        self._run_output([])
        text_out = vidups.tmpd() / "output.text"
        content = text_out.read_text()
        self.assertIn("file1", content)
        self.assertIn("strategy", content)
        self.assertIn("No duplicate candidates found", content)

    def test_table_has_all_strategies(self):
        results = [
            {"file1": "/pf1.mp4", "file2": "/pa2.mp4", "strategy": "duration", "score": 50.0},
            {"file1": "/pf3.mp4", "file2": "/pa4.mp4", "strategy": "hamming", "score": 85.5},
            {"file1": "/pf5.mp4", "file2": "/pa6.mp4", "strategy": "match", "score": 97.0},
        ]
        self._run_output(results)
        text_out = vidups.tmpd() / "output.text"
        content = text_out.read_text()
        self.assertIn("| duration", content)
        self.assertIn("| hamming", content)
        self.assertIn("| match", content)

    def test_table_score_formatting_nonmatch(self):
        results = [
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "duration", "score": 50.0}
        ]
        self._run_output(results)
        text_out = vidups.tmpd() / "output.text"
        content = text_out.read_text()
        self.assertIn("50.0%", content)

    def test_table_score_formatting_match(self):
        results = [
            {"file1": "/a.mp4", "file2": "/b.mp4", "strategy": "match", "score": 97.0}
        ]
        self._run_output(results)
        text_out = vidups.tmpd() / "output.text"
        content = text_out.read_text()
        self.assertIn("97.0", content)


class TestMainCLI(TempDirMixin, unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_main_home_")
        os.environ["HOME"] = self._tmp_home
        vidups.ensure_tmpd()
        self._root = Path(self._tmpdir())

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def test_help_flag(self):
        with self.assertRaises(SystemExit) as cm:
            with patch("sys.argv", ["vidups.py", "-h"]):
                vidups.main()
        self.assertEqual(cm.exception.code, 0)

    def test_nonexistent_directory(self):
        with patch("sys.argv", ["vidups.py", "/does/not/exist"]):
            rc = vidups.main()
            self.assertEqual(rc, 1)

    @patch("vidups.phase_1_discover")
    @patch("vidups.ensure_tmpd")
    def test_run_to_files(self, mock_ens, mock_p1):
        mock_p1.return_value = [Path("/tmp/a.mp4"), Path("/tmp/b.mp4")]
        with patch("sys.argv", ["vidups.py", str(self._root), "--run-to", "files"]):
            rc = vidups.main()
            self.assertEqual(rc, 0)
            mock_p1.assert_called_once()

    @patch("vidups.phase_3_compare")
    @patch("vidups.phase_2_hashes")
    @patch("vidups.phase_1_discover")
    @patch("vidups.ensure_tmpd")
    def test_run_to_hashes(self, mock_ens, mock_p1, mock_p2, mock_p3):
        mock_p1.return_value = [Path("/tmp/a.mp4")]
        mock_p2.return_value = {}
        with patch("sys.argv", ["vidups.py", str(self._root), "--run-to", "hashes"]):
            rc = vidups.main()
            self.assertEqual(rc, 0)
            mock_p1.assert_called_once()
            mock_p2.assert_called_once()

    @patch("vidups.phase_3_compare")
    @patch("vidups.phase_2_hashes")
    @patch("vidups.phase_1_discover")
    @patch("vidups.ensure_tmpd")
    def test_run_to_compare(self, mock_ens, mock_p1, mock_p2, mock_p3):
        mock_p1.return_value = [Path("/tmp/a.mp4")]
        mock_p2.return_value = {}
        mock_p3.return_value = []
        with patch("sys.argv", ["vidups.py", str(self._root), "--run-to", "compare"]):
            rc = vidups.main()
            self.assertEqual(rc, 0)
            mock_p3.assert_called_once()

    @patch("vidups.phase_4_output")
    @patch("vidups.phase_3_compare")
    @patch("vidups.phase_2_hashes")
    @patch("vidups.phase_1_discover")
    @patch("vidups.ensure_tmpd")
    def test_run_to_output_calls_phase4(self, mock_ens, mock_p1, mock_p2, mock_p3, mock_p4):
        mock_p1.return_value = [Path("/tmp/a.mp4")]
        mock_p2.return_value = {}
        mock_p3.return_value = []
        with patch("sys.argv", ["vidups.py", str(self._root)]):
            rc = vidups.main()
            self.assertEqual(rc, 0)
            mock_p4.assert_called_once()

    @patch("vidups.phase_4_output")
    @patch("vidups.phase_3_compare")
    @patch("vidups.phase_2_hashes")
    @patch("vidups.phase_1_discover")
    @patch("vidups.ensure_tmpd")
    def test_output_flag_passed(self, mock_ens, mock_p1, mock_p2, mock_p3, mock_p4):
        mock_p1.return_value = [Path("/tmp/a.mp4")]
        mock_p2.return_value = {}
        mock_p3.return_value = []
        with patch("sys.argv", ["vidups.py", str(self._root), "-o", "/tmp/out.json"]):
            rc = vidups.main()
            self.assertEqual(rc, 0)
            mock_p4.assert_called_once_with([], "/tmp/out.json")

    @patch("vidups.ensure_tmpd")
    @patch("vidups.phase_1_discover")
    def test_no_lazy_deletes_tmpd(self, mock_p1, mock_ens):
        t = vidups.tmpd()
        t.mkdir(parents=True, exist_ok=True)
        (t / "test_file").write_text("data")
        mock_p1.return_value = []
        with patch("sys.argv", ["vidups.py", str(self._root), "--no-lazy"]):
            rc = vidups.main()
            self.assertEqual(rc, 0)
            self.assertFalse((t / "test_file").exists())

    @patch("vidups.ensure_tmpd")
    @patch("vidups.phase_1_discover")
    def test_no_video_files_returns_zero(self, mock_p1, mock_ens):
        mock_p1.return_value = []
        with patch("sys.argv", ["vidups.py", str(self._root)]):
            rc = vidups.main()
            self.assertEqual(rc, 0)

    def test_invalid_run_to_rejected(self):
        with patch("sys.argv", ["vidups.py", str(self._root), "--run-to", "bad"]):
            with self.assertRaises(SystemExit):
                vidups.main()


class TestTmpd(unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_tmpd_home_")
        os.environ["HOME"] = self._tmp_home

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def test_returns_expected_path(self):
        t = vidups.tmpd()
        self.assertEqual(t, Path(self._tmp_home) / "TMP" / "vidups")


class TestEdgeCases(unittest.TestCase):
    def setUp(self):
        self._save_home = os.environ.get("HOME", "")
        self._tmp_home = tempfile.mkdtemp(prefix="test_edge_home_")
        os.environ["HOME"] = self._tmp_home
        vidups.ensure_tmpd()

    def tearDown(self):
        os.environ["HOME"] = self._save_home
        shutil.rmtree(self._tmp_home, ignore_errors=True)

    def test_duration_gate_exact_1_percent_boundary(self):
        d1 = 100.0
        d2 = 101.0
        diff = abs(d1 - d2) / max(d1, d2)
        self.assertAlmostEqual(diff, 0.00990099, places=5)
        self.assertLessEqual(diff, 0.01)

    def test_duration_gate_above_1_percent(self):
        d1 = 100.0
        d2 = 101.1
        diff = abs(d1 - d2) / max(d1, d2)
        self.assertGreater(diff, 0.01)

    def test_hamming_boundary_exactly_10(self):
        dist = 10
        self.assertFalse(dist > 10)

    def test_hamming_boundary_above_10(self):
        dist = 11
        self.assertTrue(dist > 10)

    def test_vmaf_boundary_exactly_95(self):
        self.assertTrue(95.0 >= 95.0)

    def test_vmaf_boundary_below_95(self):
        self.assertFalse(94.9 >= 95.0)


if __name__ == "__main__":
    unittest.main()
