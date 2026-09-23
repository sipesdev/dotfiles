"""Tests for crash-watch's core_identity. A coredump journal entry's COREDUMP_* fields are
sender-supplied and forgeable; the core file name under root-owned /var/lib/systemd/coredump
is not, so its parser is the trust boundary.

Run: python tests/agents/test_crash_watch.py   (wired into `make test`)
"""
import os
import pathlib
import signal
import subprocess
import tempfile
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


def shim(path, body):
    path.write_text(body)
    path.chmod(0o755)


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



class Announce(unittest.TestCase):
    """announce must outlive the notification server: libnotify's --wait never returns when the
    server that showed the toast exits, so crash-watch watches the bus name's owner, kills the
    stranded waiter and shows the toast again on the new server. busctl, notify-send and
    agent-crash are PATH/HOME shims; a file stands in for the bus name's owner."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = pathlib.Path(self.tmp.name)
        self.bin = root / "bin"
        self.bin.mkdir()
        (root / ".local" / "bin").mkdir(parents=True)
        self.log = root / "log"
        self.owner = root / "owner"
        self.owner.write_text('s ":1.10"\n')
        shim(self.bin / "busctl",
             "#!/bin/bash\n"
             'case "$*" in\n'
             "  *GetServerInformation*) exit 0 ;;\n"
             f"  *GetNameOwner*) cat '{self.owner}' ;;\n"
             "  *) exit 1 ;;\n"
             "esac\n")
        shim(root / ".local" / "bin" / "agent-crash",
             f"#!/bin/bash\necho \"agent-crash $*\" >> '{self.log}'\n")
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}", HOME=self.tmp.name,
                        CRASH_OWNER_POLL_SECONDS="0.2")

    def announce(self, notify_send_body):
        shim(self.bin / "notify-send", notify_send_body)
        proc = subprocess.Popen(["bash", "-c", 'source "$1"; announce sleep 4242 SIGSEGV; wait', "_", str(SCRIPT)],
                                env=self.env, start_new_session=True, stderr=subprocess.DEVNULL)
        # The whole tree is one process group, so a regression that leaves a shim's waiter hanging
        # is killed here by group, never by a command-line pattern (which on this machine would
        # also match the eGPU suspend inhibitor's `sleep infinity`).
        self.addCleanup(self.kill_group, proc)
        proc.wait(timeout=20)
        self.assertEqual(proc.returncode, 0)
        # setsid does not fork here (the announcing subshell is never a group leader), so
        # agent-crash has written its line by the time `wait` returns.
        return self.log.read_text().splitlines() if self.log.exists() else []

    @staticmethod
    def kill_group(proc):
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def test_dismissed_toast_ends_the_announcement(self):
        lines = self.announce(f"#!/bin/bash\necho \"notify-send $*\" >> '{self.log}'\n")
        self.assertEqual(len(lines), 1)
        self.assertIn("Process crashed: sleep", lines[0])

    def test_click_launches_agent_crash_with_the_trusted_facts(self):
        lines = self.announce(f"#!/bin/bash\necho \"notify-send $*\" >> '{self.log}'\necho default\n")
        self.assertEqual(lines[-1], "agent-crash 4242 sleep SIGSEGV")

    def test_toast_is_shown_again_when_the_server_is_replaced(self):
        # First call: the toast is up, then the server restarts under it (new owner) and the
        # waiter hangs the way libnotify does. Second call: the new server shows it; dismissed.
        lines = self.announce(
            "#!/bin/bash\n"
            f"echo \"notify-send $*\" >> '{self.log}'\n"
            f"if [[ $(grep -c '^notify-send' '{self.log}') == 1 ]]; then\n"
            f"  echo 's \":1.20\"' > '{self.owner}'\n"
            "  exec sleep infinity\n"
            "fi\n")
        self.assertEqual(len(lines), 2)
        self.assertTrue(all(line.startswith("notify-send") for line in lines))

    def test_owner_lookup_failure_does_not_kill_the_waiter(self):
        # busctl can fail transiently while the server is alive. An empty answer must not read
        # as "the owner changed": that kills a live waiter and re-sends the toast on the same
        # server, leaving a dead card behind. Calls 2 and 3 fail; the toast must ride it out.
        calls = pathlib.Path(self.tmp.name) / "calls"
        shim(self.bin / "busctl",
             "#!/bin/bash\n"
             'case "$*" in\n'
             "  *GetServerInformation*) exit 0 ;;\n"
             "  *GetNameOwner*)\n"
             f"    n=$(( $(cat '{calls}' 2>/dev/null || echo 0) + 1 )); echo $n > '{calls}'\n"
             "    [[ $n == 2 || $n == 3 ]] && exit 1\n"
             f"    cat '{self.owner}' ;;\n"
             "  *) exit 1 ;;\n"
             "esac\n")
        lines = self.announce(f"#!/bin/bash\necho \"notify-send $*\" >> '{self.log}'\n"
                              f"sleep 1\necho 'notify-send done' >> '{self.log}'\n")
        self.assertEqual(lines, [lines[0], "notify-send done"])
        self.assertTrue(lines[0].startswith("notify-send"))

if __name__ == "__main__":
    unittest.main()
