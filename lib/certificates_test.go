package lib

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestStaticClientNetwork(t *testing.T) {
	path := filepath.Join(t.TempDir(), "server.conf")
	for voie := 1; voie <= 3; voie++ {
		conf := fmt.Sprintf("topology subnet\nserver 10.%d.0.0 255.255.0.0 nopool\n", voie)
		if err := os.WriteFile(path, []byte(conf), 0600); err != nil {
			t.Fatal(err)
		}
		ip := fmt.Sprintf("10.%d.42.7", voie)
		got, err := staticClientConfig(ip, path)
		if err != nil || got != "ifconfig-push "+ip+" 255.255.0.0\n" {
			t.Fatalf("%q, %v", got, err)
		}
		for _, invalid := range []string{"192.168.1.9", "not-an-ip", fmt.Sprintf("10.%d.0.0", voie), fmt.Sprintf("10.%d.0.1", voie), fmt.Sprintf("10.%d.255.255", voie)} {
			if _, err := staticClientConfig(invalid, path); err == nil {
				t.Errorf("accepted unavailable address %q", invalid)
			}
		}
	}
}
