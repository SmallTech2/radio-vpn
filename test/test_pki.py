"""Certificats et CRL reels en repertoires temporaires ; aucun daemon OpenVPN."""
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "Radio/scripts"


@unittest.skipUnless(os.environ.get("EASYRSA_TEST_SOURCE"), "requires Easy-RSA 3.2.2 and OpenVPN CLI")
class PKILifecycle(unittest.TestCase):
    def test_profiles_and_revocation_survive_cleanup_and_crl_refresh(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            rsa, ovpn = root / "rsa", root / "ovpn"
            shutil.copytree(os.environ["EASYRSA_TEST_SOURCE"], rsa)
            (rsa / "easyrsa").chmod(0o755)
            for name in ("config", "clients", "staticclients"):
                (ovpn / name).mkdir(parents=True)
            (root / "app.conf").write_text(f'EasyRsaPath = "{rsa}"\nOpenVpnPath = "{ovpn}"\n')
            (ovpn / "config/easy-rsa.vars").write_text(
                'set_var EASYRSA_DN "cn_only"\nset_var EASYRSA_REQ_CN "Radio Test CA"\n'
                'set_var EASYRSA_KEY_SIZE 2048\nset_var EASYRSA_CRL_DAYS 180\n')
            client = (ROOT / "Radio/config/openvpn-client-config.tpl").read_text().replace("{{ .ServerAddress }}", "203.0.113.7")
            (ovpn / "config/client.conf").write_text(client)
            env = dict(os.environ, OPENVPN_UI_CONFIG=str(root / "app.conf"), EASYRSA_BATCH="1",
                       EASYRSA_CERT_EXPIRE="1", EASYRSA_REQ_EMAIL="test@example.org", TFA_NAME="none")

            def run(*args, ok=True, cwd=root):
                result = subprocess.run(args, cwd=cwd, env=env, capture_output=True, text=True, timeout=240)
                if ok:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                return result

            def script(name, *args, **kwargs):
                return run("bash", str(SCRIPTS / name), *args, **kwargs)

            def serial(path):
                return run("openssl", "x509", "-in", str(path), "-noout", "-serial").stdout.strip().split("=", 1)[1]

            script("generate_ca_and_server_certs.sh", "init_all")
            ca_hash = hashlib.sha256((rsa / "pki/ca.crt").read_bytes()).hexdigest()
            script("generate_ca_and_server_certs.sh", "init_all", ok=False)
            self.assertEqual(ca_hash, hashlib.sha256((rsa / "pki/ca.crt").read_bytes()).hexdigest())
            script("genclient.sh", "studio1", "10.1.42.7", "")
            profile = (ovpn / "clients/studio1.ovpn").read_text()
            for block in ("ca", "cert", "key", "tls-crypt"):
                self.assertEqual(profile.count(f"<{block}>"), 1)
                self.assertEqual(profile.count(f"</{block}>"), 1)
            pem = re.search(r"<cert>\s*(.*?)\s*</cert>", profile, re.S).group(1)
            parsed = subprocess.run(["openssl", "x509", "-noout"], input=pem, text=True, capture_output=True)
            self.assertEqual(parsed.returncode, 0, parsed.stderr)
            issued = rsa / "pki/issued/studio1.crt"
            old_serial = serial(issued)
            old_cert = root / "before-renewal.crt"
            shutil.copy(issued, old_cert)
            script("rmcert.sh", "studio1", old_serial, ok=False)
            script("renew.sh", "studio1", "10.1.42.7", old_serial)
            new_serial = serial(issued)
            self.assertNotEqual(old_serial, new_serial)
            renewed_cert = root / "after-renewal.crt"
            shutil.copy(issued, renewed_cert)
            script("revoke.sh", "studio1", old_serial)
            script("rmcert.sh", "studio1", old_serial)
            self.assertTrue((ovpn / "clients/studio1.ovpn").exists(), "valid renewed profile was deleted")
            run("openssl", "verify", "-crl_check", "-CAfile", str(rsa / "pki/ca.crt"),
                "-CRLfile", str(rsa / "pki/crl.pem"), str(issued))
            script("revoke.sh", "studio1", new_serial)
            script("rmcert.sh", "studio1", new_serial)
            self.assertFalse((ovpn / "clients/studio1.ovpn").exists())
            # Equivalent au renouvellement hebdomadaire : les deux series restent revoquees.
            script("generate_ca_and_server_certs.sh", "gen_crl")
            index = (rsa / "pki/index.txt").read_text()
            for number in (old_serial, new_serial):
                self.assertTrue(any(line.startswith("R\t") and line.split("\t")[3] == number for line in index.splitlines()))
            # Easy-RSA deplace les certificats revoques : verifier les copies conservees.
            for certificate in (old_cert, renewed_cert):
                rejected = run("openssl", "verify", "-crl_check", "-CAfile", str(rsa / "pki/ca.crt"),
                               "-CRLfile", str(rsa / "pki/crl.pem"), str(certificate), ok=False)
                self.assertIn("certificate revoked", rejected.stderr.lower())


if __name__ == "__main__":
    unittest.main()
