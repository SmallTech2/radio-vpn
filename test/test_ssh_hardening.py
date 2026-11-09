"""Tests du helper avec commandes systeme simulees, sans acces a un serveur."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASH = "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "/bin/bash"
HELPER = ROOT / "Radio/scripts/secure-ssh.sh"

MOCKS = r'''
getent(){
  [[ "$*" == "passwd $TEST_USER" ]] || return 1
  printf '%s:x:1000:1000::/home/%s:/bin/bash\n' "$TEST_USER" "$TEST_USER"
}
ssh-keygen(){
  [[ "$*" == "-lf /home/$TEST_USER/.ssh/authorized_keys" ]] || return 1
  printf '256 SHA256:fixture test (ED25519)\n'
}
journalctl(){
  [[ "$TEST_CASE" != journal-error ]] || return 1
  if [[ "${TEST_AUTO:-no}" == yes ]]; then
    [[ "$*" == '-b -u ssh --after-cursor=fixture-cursor --no-pager -o cat' ]] || return 1
    # Une ancienne connexion existe, mais aucune nouvelle entree apres le curseur.
    [[ "$TEST_CASE" != old-connection && "$TEST_CASE" != multiplexed ]] || return 0
  fi
  if [[ "$TEST_CASE" == wrong-key ]]; then
    echo "Accepted publickey for $TEST_USER from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:other"
  elif [[ "$TEST_CASE" == wrong-user ]]; then
    echo 'Accepted publickey for other from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:fixture'
  elif [[ "$TEST_CASE" == password ]]; then
    echo "Accepted password for $TEST_USER from 192.0.2.10 port 50000 ssh2"
  elif [[ "$TEST_CASE" == key-prefix ]]; then
    echo "Accepted publickey for $TEST_USER from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:fixtureOTHER"
  else
    echo "Accepted publickey for $TEST_USER from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:fixture"
  fi
}
cp(){ if [[ "$1" == -p ]]; then shift; fi; command cp "$@"; }
test_sshd(){
  printf 'sshd %s\n' "$*" >> "$TEST_TRACE"
  if [[ "$1" == -t ]]; then
    if [[ "$TEST_CASE" == syntax-error && ! -f "$TEST_FAILED" ]]; then touch "$TEST_FAILED"; return 1; fi
    return 0
  fi
  [[ "$TEST_CASE" != effective-error ]] || return 1
  if [[ "$*" != '-T' ]]; then
    [[ "$*" == "-T -C user=$TEST_USER,addr=192.0.2.10,host=192.0.2.10,laddr=192.0.2.20,lport=2222" ]] || return 1
  fi
  case "$TEST_CASE" in
    bad-pubkey) echo 'pubkeyauthentication no' ;;
    *) echo 'pubkeyauthentication yes' ;;
  esac
  if [[ "$TEST_CASE" == bad-methods ]]; then echo 'authenticationmethods any'; else echo 'authenticationmethods publickey'; fi
  if [[ "$TEST_CASE" == bad-password ]]; then echo 'passwordauthentication yes'; else echo 'passwordauthentication no'; fi
  if [[ "$TEST_CASE" == bad-keyboard ]]; then echo 'kbdinteractiveauthentication yes'; else echo 'kbdinteractiveauthentication no'; fi
}
systemctl(){
  [[ "$*" == 'reload ssh' ]] || return 1
  printf 'reload ssh\n' >> "$TEST_TRACE"
  if [[ "$TEST_CASE" == reload-error && ! -f "$TEST_FAILED" ]]; then touch "$TEST_FAILED"; return 1; fi
}
'''


class SSHHardeningTest(unittest.TestCase):
    def run_case(self, case, user="alice", automatic=False):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, trace = root / "sshd.conf", root / "trace"
            original = "PubkeyAuthentication yes\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\n"
            config.write_text(original, encoding="utf-8", newline="\n")
            trace.write_text("")
            # Seule la copie de test remplace la garde root et les chemins systeme.
            helper = HELPER.read_text(encoding="utf-8")
            helper = helper.replace("[[ $EUID -eq 0 ]] || { echo 'Executer avec sudo.' >&2; exit 1; }", ":")
            helper = helper.replace("CONFIG=/etc/ssh/sshd_config.d/00-radio.conf", 'CONFIG="$TEST_CONFIG"')
            helper = helper.replace("/usr/sbin/sshd", "test_sshd")
            env = dict(os.environ, SUDO_USER=user, TEST_USER=user, TEST_CASE=case,
                       SSH_CONNECTION="192.0.2.10 50000 192.0.2.20 2222",
                       TEST_CONFIG=config.as_posix(), TEST_TRACE=trace.as_posix(),
                       TEST_FAILED=(root / "failed").as_posix(), TEST_AUTO="yes" if automatic else "no")
            args = "set -- --after-cursor fixture-cursor 192.0.2.20 2222\n" if automatic else ""
            result = subprocess.run([BASH], input=MOCKS + args + helper, encoding="utf-8", capture_output=True, env=env)
            return result, config.read_text(), trace.read_text(), original

    def test_success_for_configurable_accounts(self):
        for user in ("technicien", "alice", "ops-admin_2", "_admin", "a" * 32):
            with self.subTest(user=user):
                result, config, trace, _ = self.run_case("success", user)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("PasswordAuthentication no\n", config)
                self.assertIn("KbdInteractiveAuthentication no\n", config)
                self.assertIn("AuthenticationMethods publickey\n", config)
                self.assertIn("user=" + user + ",addr=", trace)
                self.assertEqual(trace.count("reload ssh"), 1)

    def test_no_change_without_key_proof(self):
        for case in ("wrong-key", "wrong-user", "journal-error"):
            with self.subTest(case=case):
                result, config, trace, original = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(config, original)
                self.assertEqual(trace, "")

    def test_automatic_new_key_connection_for_custom_accounts(self):
        for user in ("technicien", "alice", "ops-admin_2", "_admin", "a" * 32):
            with self.subTest(user=user):
                result, config, trace, _ = self.run_case("success", user, automatic=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("AuthenticationMethods publickey\n", config)
                self.assertIn("PasswordAuthentication no\n", config)
                self.assertIn("KbdInteractiveAuthentication no\n", config)
                self.assertIn("user=" + user + ",addr=", trace)
                self.assertEqual(trace.count("reload ssh"), 1)

    def test_automatic_confirmation_requires_fresh_matching_key_proof(self):
        for case in ("old-connection", "multiplexed", "password", "wrong-user", "wrong-key", "key-prefix", "journal-error"):
            with self.subTest(case=case):
                result, config, trace, original = self.run_case(case, automatic=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(config, original)
                self.assertEqual(trace, "")
                self.assertIn("configuration inchangee", result.stderr.lower())

    def test_restore_on_validation_or_reload_failure(self):
        for case in ("syntax-error", "effective-error", "bad-pubkey", "bad-methods",
                     "bad-password", "bad-keyboard", "reload-error"):
            with self.subTest(case=case):
                for automatic in (False, True):
                    result, config, trace, original = self.run_case(case, automatic=automatic)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(config, original)
                    self.assertIn("reload ssh", trace)


class MandatorySSHValidationTest(unittest.TestCase):
    def run_gate(self, inputs, exists="yes", proof="yes", journal="yes"):
        source = (ROOT / "Radio/deploy-vps.sh").read_text(encoding="utf-8")
        start = source.index("require_secure_admin_ssh(){")
        gate = source[start:source.index("\nconfirm_install(){", start)]
        gate = gate.replace("/dev/tty", "/dev/null")
        gate = gate.replace("[[ -x /usr/local/bin/radio-secure-ssh ]]", '[[ "$TEST_HELPER_EXISTS" == yes ]]')
        gate = gate.replace("/usr/local/bin/radio-secure-ssh", "test_helper")
        setup = r'''
set -eu
log(){ :; }
die(){ echo "$*" >&2; exit 1; }
input_index=0
read(){
  (( input_index < ${#inputs[@]} )) || return 1
  printf -v "${@: -1}" '%s' "${inputs[input_index]}"
  input_index=$((input_index+1))
}
test_helper(){
  [[ "$SUDO_USER" == ops-admin_2 ]] || return 1
  [[ "$*" == '--after-cursor fixture-cursor 192.0.2.20 2222' ]] || return 1
  [[ "$TEST_PROOF" == yes ]]
}
journalctl(){
  [[ "$input_index" == 0 ]] || return 1
  [[ "$*" == '-b -u ssh -n 1 --show-cursor --no-pager -o cat' ]] || return 1
  [[ "$TEST_JOURNAL" != error ]] || return 1
  [[ "$TEST_JOURNAL" != empty ]] || return 0
  echo '-- cursor: fixture-cursor'
}
'''
        import shlex
        setup += "\ninputs=(" + " ".join(shlex.quote(value) for value in inputs) + ")\n"
        script = setup + gate + '\nrequire_secure_admin_ssh ops-admin_2 192.0.2.20\necho GATE_PASSED\n'
        return subprocess.run([BASH], input=script, encoding="utf-8", capture_output=True,
                              env=dict(os.environ, SUDO_USER="root", TEST_HELPER_EXISTS=exists, TEST_PROOF=proof, TEST_JOURNAL=journal,
                                       SSH_CONNECTION="192.0.2.11 50100 192.0.2.20 2222"))

    def test_retry_then_confirm_as_selected_user(self):
        result = self.run_gate(["non", "oui"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("GATE_PASSED", result.stdout)
        self.assertIn("-o PasswordAuthentication=no", result.stdout)
        self.assertIn("-p 2222 ops-admin_2@192.0.2.20", result.stdout)
        self.assertNotIn('echo "$SSH_CONNECTION"', result.stdout)

    def test_cannot_continue_without_proof_or_helper(self):
        for inputs, exists, proof, journal in ((["oui"], "yes", "no", "yes"), ([], "no", "yes", "yes"),
                                               (["oui"], "yes", "yes", "error"), (["oui"], "yes", "yes", "empty")):
            result = self.run_gate(inputs, exists, proof, journal)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("GATE_PASSED", result.stdout)

    def test_gate_before_vpn_initialization(self):
        source = (ROOT / "Radio/deploy-vps.sh").read_text(encoding="utf-8")
        self.assertLess(source.index('  require_secure_admin_ssh "$admin_user" "$public_ip"'),
                        source.index("./openvpn-ui -initialize-only"))
        self.assertIn('install -m 755 "$TMP/src/Radio/scripts/secure-ssh.sh" /usr/local/bin/radio-secure-ssh', source)
        self.assertNotIn("printf 'PubkeyAuthentication yes\\nPasswordAuthentication yes\\n'", source)

    def test_existing_ssh_fragment_is_preserved_before_key_proof(self):
        source = (ROOT / "Radio/deploy-vps.sh").read_text(encoding="utf-8")
        start = source.index("  if [[ ! -e /etc/ssh/sshd_config.d/00-radio.conf ]]")
        snippet = source[start:source.index("\n  /usr/sbin/sshd -t", start)]
        snippet = snippet.replace("/etc/ssh/sshd_config.d/00-radio.conf", '"$TEST_CONFIG"')
        with tempfile.TemporaryDirectory() as directory:
            config = pathlib.Path(directory) / "00-radio.conf"
            for original in (None, "PasswordAuthentication no\nKbdInteractiveAuthentication no\n"):
                if original is not None:
                    config.write_text(original, encoding="utf-8", newline="\n")
                result = subprocess.run([BASH], input=snippet, encoding="utf-8", capture_output=True,
                                        env=dict(os.environ, TEST_CONFIG=config.as_posix()))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(config.read_text(), original or "PubkeyAuthentication yes\n")


if __name__ == "__main__":
    unittest.main()
