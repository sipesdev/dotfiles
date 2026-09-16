"""Tests for crash-watch's core_identity. A coredump journal entry's COREDUMP_* fields are
sender-supplied and forgeable; the core file name under root-owned /var/lib/systemd/coredump
is not, so its parser is the trust boundary.

Run: python tests/agents/test_crash_watch.py   (wired into `make test`)
"""
import pathlib
import subprocess
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = REPO / "localbin" / ".local" / "bin" / "crash-watch"
CORE_DIR = "/var/lib/systemd/coredump"
BOOT = "5fbf14717d0742aaa171754429aa8097"


def core_identity(path):
    # main() is guarded by BASH_SOURCE, so sourcing defines the functions and runs nothing.
    r = subprocess.run(["bash", "-c", 'source "$1"; core_identity "$2"', "_", str(SCRIPT), path],
                       capture_output=True, text=True)
    return r.returncode, r.stdout


class CoreIdentity(unittest.TestCase):
    def test_compressed_core_with_escaped_comm(self):
        self.assertEqual(
            core_identity(f"{CORE_DIR}/core.Borderlands4\\x2eex.1000.{BOOT}.51080.1788851045000000.zst"),
            (0, "Borderlands4.ex 1000 51080\n"))

    def test_uncompressed_core(self):
        self.assertEqual(core_identity(f"{CORE_DIR}/core.sleep.1000.{BOOT}.4242.1788851045000000"),
                         (0, "sleep 1000 4242\n"))

    def test_rejects_other_directory(self):
        self.assertEqual(core_identity(f"/tmp/core.sleep.1000.{BOOT}.4242.1788851045000000")[0], 1)
        self.assertEqual(core_identity(f"{CORE_DIR}/../core.sleep.1000.{BOOT}.4242.1")[0], 1)

    def test_rejects_non_core_names(self):
        self.assertEqual(core_identity(f"{CORE_DIR}/notes.txt")[0], 1)
        self.assertEqual(core_identity(f"{CORE_DIR}/core.sleep.abc.{BOOT}.4242.1")[0], 1)
        self.assertEqual(core_identity(f"{CORE_DIR}/core.sleep.1000.{BOOT}.pid.1")[0], 1)
        self.assertEqual(core_identity(f"{CORE_DIR}/core.sleep.1000.notaboot.4242.1")[0], 1)

    def test_rejects_missing_field_marker(self):
        self.assertEqual(core_identity("-")[0], 1)

    def test_rejects_comm_that_decodes_to_separators(self):
        # comm is the process's own choice; a space or newline smuggled through the
        # \xHH escaping would re-split "<comm> <uid> <pid>" for the caller.
        self.assertEqual(core_identity(f"{CORE_DIR}/core.x\\x201000\\x209999.1001.{BOOT}.4242.1.zst")[0], 1)
        self.assertEqual(core_identity(f"{CORE_DIR}/core.x\\x0ay.1000.{BOOT}.4242.1.zst")[0], 1)

    def test_rejects_control_bytes_in_comm(self):
        self.assertEqual(core_identity(f"{CORE_DIR}/core.a\\x1b[31m.1000.{BOOT}.4242.1.zst")[0], 1)

    def test_keeps_printable_escapes(self):
        self.assertEqual(core_identity(f"{CORE_DIR}/core.a\\x2fb.1000.{BOOT}.4242.1.zst"),
                         (0, "a/b 1000 4242\n"))


if __name__ == "__main__":
    unittest.main()
