package models

import (
	"fmt"
	"strings"
	"testing"

	"github.com/beego/beego/v2/server/web"
	clientconfig "github.com/d3vilh/openvpn-server-config/client/client-config"
	easyrsaconfig "github.com/d3vilh/openvpn-server-config/easyrsa/config"
	serverconfig "github.com/d3vilh/openvpn-server-config/server/config"
)

func TestRadioPKIEmail(t *testing.T) {
	oldNetwork := web.AppConfig.DefaultString("RadioVpnNetwork", "")
	oldIP := web.AppConfig.DefaultString("RadioPublicIP", "")
	oldEmail := web.AppConfig.DefaultString("RadioPKIEmail", "")
	t.Cleanup(func() {
		web.AppConfig.Set("RadioVpnNetwork", oldNetwork)
		web.AppConfig.Set("RadioPublicIP", oldIP)
		web.AppConfig.Set("RadioPKIEmail", oldEmail)
	})
	web.AppConfig.Set("RadioVpnNetwork", "10.3.0.0/16")
	web.AppConfig.Set("RadioPublicIP", "203.0.113.7")
	for _, email := range []string{"", "pki@example.org", "vpn+admin@example.net"} {
		web.AppConfig.Set("RadioPKIEmail", email)
		var config easyrsaconfig.Config
		if err := ApplyRadioEasyRSAConfig(&config); err != nil {
			t.Fatal(err)
		}
		expected := email
		if expected == "" {
			expected = "contact@example.org"
		}
		if config.EasyRSAReqEmail != expected {
			t.Fatalf("PKI email: got %q, want %q", config.EasyRSAReqEmail, expected)
		}
	}
}

func TestRadioDeploymentDefaults(t *testing.T) {
	oldNetwork := web.AppConfig.DefaultString("RadioVpnNetwork", "")
	oldIP := web.AppConfig.DefaultString("RadioPublicIP", "")
	t.Cleanup(func() { web.AppConfig.Set("RadioVpnNetwork", oldNetwork); web.AppConfig.Set("RadioPublicIP", oldIP) })
	for voie := 1; voie <= 3; voie++ {
		t.Run(fmt.Sprint(voie), func(t *testing.T) {
			network := fmt.Sprintf("10.%d.0.0", voie)
			web.AppConfig.Set("RadioVpnNetwork", network)
			web.AppConfig.Set("RadioPublicIP", "203.0.113.7")
			server := serverconfig.New()
			if err := ApplyRadioServerConfig(&server); err != nil {
				t.Fatal(err)
			}
			if server.Server != "server "+network+" 255.255.0.0 nopool" {
				t.Fatal(server.Server)
			}
			if server.Route != "" || server.PushRoute != "" || server.RedirectGW != "" {
				t.Fatal("historical routes retained")
			}
			if !strings.Contains(server.CustomOptTwo, "client-to-client") || !strings.Contains(server.CustomOptTwo, "ccd-exclusive") {
				t.Fatal("fixed client requirements missing")
			}
			client := clientconfig.New()
			if err := ApplyRadioClientConfig(&client); err != nil {
				t.Fatal(err)
			}
			if client.ServerAddress != "203.0.113.7" || client.RedirectGateway != "" {
				t.Fatalf("bad client: %+v", client)
			}
			// Une seconde sauvegarde GUI doit produire les memes parametres.
			server.Server, server.RedirectGW = "server 10.0.70.0 255.255.255.0", "push redirect-gateway def1"
			ApplyRadioServerConfig(&server)
			if server.Server != "server "+network+" 255.255.0.0 nopool" || server.RedirectGW != "" {
				t.Fatal("GUI reintroduced obsolete defaults")
			}
		})
	}
	web.AppConfig.Set("RadioVpnNetwork", "10.4.0.1/16")
	if _, err := RadioNetwork(); err == nil {
		t.Fatal("unsupported network accepted")
	}
	web.AppConfig.Set("RadioVpnNetwork", "10.1.0.0")
	web.AppConfig.Set("RadioPublicIP", "127.0.0.1")
	if _, err := RadioNetwork(); err == nil {
		t.Fatal("loopback public IP accepted")
	}
	web.AppConfig.Set("RadioVpnNetwork", "")
	server := serverconfig.New()
	before := server.Server
	if err := ApplyRadioServerConfig(&server); err != nil || server.Server != before {
		t.Fatal("non-Radio defaults changed")
	}
}
