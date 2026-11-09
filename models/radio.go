package models

import (
	"fmt"
	"net"
	"strings"

	"github.com/beego/beego/v2/server/web"
	clientconfig "github.com/d3vilh/openvpn-server-config/client/client-config"
	easyrsaconfig "github.com/d3vilh/openvpn-server-config/easyrsa/config"
	serverconfig "github.com/d3vilh/openvpn-server-config/server/config"
)

// RadioNetwork retourne le reseau du VPS ; nil conserve le comportement hors Radio.
func RadioNetwork() (*net.IPNet, error) {
	network := web.AppConfig.DefaultString("RadioVpnNetwork", "")
	if network == "" {
		return nil, nil
	}
	// Les installations existantes sans prefixe conservent leur masque /16.
	if !strings.Contains(network, "/") {
		network += "/16"
	}
	ip, subnet, err := net.ParseCIDR(network)
	if err != nil || ip.To4() == nil {
		return nil, fmt.Errorf("RadioVpnNetwork doit etre un reseau IPv4 prive en CIDR")
	}
	ones, _ := subnet.Mask.Size()
	last := append(net.IP(nil), subnet.IP...)
	for i := range last {
		last[i] |= ^subnet.Mask[i]
	}
	if !ip.Equal(subnet.IP) || !ip.IsPrivate() || !last.IsPrivate() || ones < 16 || ones > 29 {
		return nil, fmt.Errorf("RadioVpnNetwork doit etre une adresse reseau RFC1918, de /16 a /29 (limites OpenVPN)")
	}
	publicIP := net.ParseIP(web.AppConfig.DefaultString("RadioPublicIP", ""))
	if publicIP == nil || publicIP.To4() == nil || publicIP.IsUnspecified() || publicIP.IsLoopback() || publicIP.IsMulticast() {
		return nil, fmt.Errorf("RadioPublicIP doit contenir l'IPv4 du VPS")
	}
	return subnet, nil
}

// Ces valeurs sont aussi appliquees aux sauvegardes GUI pour eviter les anciens defauts.
func ApplyRadioServerConfig(c *serverconfig.Config) error {
	subnet, err := RadioNetwork()
	if err != nil || subnet == nil {
		return err
	}
	c.Device = "tun0"
	c.OVConfigTopology = "subnet"
	c.Server = "server " + subnet.IP.String() + " " + net.IP(subnet.Mask).String() + " nopool"
	c.Route, c.PushRoute, c.RedirectGW = "", "", ""
	c.DNSServer1, c.DNSServer2 = "", ""
	c.CustomOptTwo = "client-to-client\nccd-exclusive"
	return nil
}

func ApplyRadioClientConfig(c *clientconfig.Config) error {
	subnet, err := RadioNetwork()
	if err != nil || subnet == nil {
		return err
	}
	c.ServerAddress = web.AppConfig.DefaultString("RadioPublicIP", "")
	c.RedirectGateway = ""
	return nil
}

func ApplyRadioEasyRSAConfig(c *easyrsaconfig.Config) error {
	subnet, err := RadioNetwork()
	if err != nil || subnet == nil {
		return err
	}
	c.EasyRSAReqCountry = "FR"
	c.EasyRSAReqProvince, c.EasyRSAReqCity = "BR", "Pleneuf-Val-Andre"
	c.EasyRSAReqOrg = web.AppConfig.DefaultString("RadioPKIOrganization", "Radio Bonheur")
	c.EasyRSAReqEmail = web.AppConfig.DefaultString("RadioPKIEmail", "contact@example.org")
	c.EasyRSAReqOu = "VPN " + subnet.IP.String()
	return nil
}
