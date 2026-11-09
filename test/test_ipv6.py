"""Desactivation IPv6 en repertoires temporaires, sans modifier le reseau de l'hote."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASH = "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "/bin/bash"


class IPv6Configuration(unittest.TestCase):
    def run_case(self, case):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config = root / "sysctl.d/99-radio-disable-ipv6.conf"
            config.parent.mkdir()
            proc = root / "proc"
            if case != "kernel-disabled":
                for name in ("all", "default", "lo", "eth0"):
                    (proc / name).mkdir(parents=True)
                    (proc / name / "disable_ipv6").write_text("0\n")
            source = (ROOT / "Radio/deploy-vps.sh").read_text(encoding="utf-8")
            start = source.index("disable_ipv6(){")
            function = source[start:source.index("\nrequire_password(){", start)]
            function = function.replace("config=/etc/sysctl.d/99-radio-disable-ipv6.conf", 'config="$TEST_CONFIG"')
            function = function.replace("/etc/sysctl.d", '"$TEST_CONFIG_DIR"')
            function = function.replace("/proc/sys/net/ipv6/conf", '"$TEST_PROC"')
            mocks = r'''
set -eu
log(){ :; }
die(){ echo "$*" >&2; exit 1; }
install(){ [[ "$*" == "-d -m 755 $TEST_CONFIG_DIR" ]]; }
ss(){
  [[ "$*" == '-H -6 -tnp state established' ]] || return 1
  [[ "$TEST_CASE" != ss-error ]] || return 1
  if [[ "$TEST_CASE" == ssh-ipv6 ]]; then
    echo '0 0 [2001:db8::1]:22 [2001:db8::2]:50000 users:(("sshd-session",pid=123,fd=4))'
  fi
}
sysctl(){
  [[ "$*" == "-p $TEST_CONFIG" ]] || return 1
  echo called > "$TEST_TRACE"
  [[ "$TEST_CASE" != sysctl-error ]] || return 1
  for setting in "$TEST_PROC"/*/disable_ipv6; do
    if [[ "$TEST_CASE" != verify-error || "$setting" != */eth0/* ]]; then
      printf '1\n' > "$setting"
    fi
  done
}
'''
            env = dict(os.environ, TEST_CASE=case, TEST_CONFIG=config.as_posix(),
                       TEST_CONFIG_DIR=config.parent.as_posix(), TEST_PROC=proc.as_posix(),
                       TEST_TRACE=(root / "trace").as_posix())
            result = subprocess.run([BASH], input=mocks + function + "\ndisable_ipv6\necho DONE\n",
                                    text=True, capture_output=True, env=env)
            return result, config.read_text() if config.exists() else None, (root / "trace").exists()

    def test_apply_and_persist_or_already_disabled(self):
        expected = "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\n"
        for case in ("success", "kernel-disabled"):
            with self.subTest(case=case):
                result, config, applied = self.run_case(case)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(config, expected)
                self.assertEqual(applied, case == "success")

    def test_refuse_active_ipv6_ssh_before_changes(self):
        for case in ("ssh-ipv6", "ss-error"):
            with self.subTest(case=case):
                result, config, applied = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(config)
                self.assertFalse(applied)

    def test_cannot_succeed_when_apply_or_verification_fails(self):
        for case in ("sysctl-error", "verify-error"):
            with self.subTest(case=case):
                result, _, applied = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("DONE", result.stdout)
                self.assertTrue(applied)

    def test_guard_and_installation_order(self):
        source = (ROOT / "Radio/deploy-vps.sh").read_text(encoding="utf-8")
        guard = next(line for line in source.splitlines() if '"${SSH_CONNECTION:-${SSH_CLIENT:-}}"' in line)
        for connection, client, expected in (("192.0.2.2 50000 192.0.2.1 22", "", 0),
                                              ("2001:db8::2 50000 2001:db8::1 22", "", 1),
                                              ("", "2001:db8::2 50000 22", 1), ("", "", 0)):
            result = subprocess.run([BASH], input='die(){ exit 1; }\n' + guard + '\n', text=True,
                                    capture_output=True, env=dict(os.environ, SSH_CONNECTION=connection, SSH_CLIENT=client))
            self.assertEqual(result.returncode, expected)
        self.assertLess(source.index(guard), source.index("  prepare_debian\n"))
        self.assertLess(source.index('  require_secure_admin_ssh "$admin_user" "$public_ip"'), source.index("  disable_ipv6\n"))
        self.assertLess(source.index("  disable_ipv6\n"), source.index("  activate_firewall\n"))
        self.assertIn("ssh -4 -o ControlMaster=no", source)
        self.assertIn("iproute2 util-linux procps", source)


if __name__ == "__main__":
    unittest.main()
