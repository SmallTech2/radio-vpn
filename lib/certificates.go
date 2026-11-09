package lib

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/beego/beego/v2/core/logs"
	"github.com/SmallTech2/radio-vpn/models"
	"github.com/SmallTech2/radio-vpn/state"
)

// Cert
// https://groups.google.com/d/msg/mailing.openssl.users/gMRbePiuwV0/wTASgPhuPzkJ
type Cert struct {
	EntryType   string
	Expiration  string
	ExpirationT time.Time
	IsExpiring  bool
	Revocation  string
	RevocationT time.Time
	Serial      string
	FileName    string
	Details     *Details
}

type Details struct {
	Name             string
	CN               string
	Country          string
	State            string
	City             string
	Organisation     string
	OrganisationUnit string
	Email            string
	LocalIP          string
	TFAName          string
}

func ReadCerts(path string) ([]*Cert, error) {
	certs := make([]*Cert, 0)
	text, err := os.ReadFile(path)
	if err != nil {
		return certs, err
	}
	lines := strings.Split(trim(string(text)), "\n")
	for _, line := range lines {
		fields := strings.Split(trim(line), "\t")
		if len(fields) != 6 {
			return certs,
				fmt.Errorf("incorrect number of lines in line: \n%s\n. Expected %d, found %d",
					line, 6, len(fields))
		}
		expT, _ := time.Parse("060102150405Z", fields[1])
		expTA := time.Now().AddDate(0, 0, 30).After(expT) // If cer will expire in 30 days, raise this flag
		//logs.Debug("ExpirationT: %v, IsExpiring: %v", expT, expTA) // logging
		revT, _ := time.Parse("060102150405Z", fields[2])
		c := &Cert{
			EntryType:   fields[0],
			Expiration:  fields[1],
			ExpirationT: expT,
			IsExpiring:  expTA,
			Revocation:  fields[2],
			RevocationT: revT,
			Serial:      fields[3],
			FileName:    fields[4],
			Details:     parseDetails(fields[5]),
		}
		certs = append(certs, c)
	}

	return certs, nil
}

func parseDetails(d string) *Details {
	details := &Details{}
	lines := strings.Split(trim(d), "/")
	for _, line := range lines {
		if strings.Contains(line, "") {
			fields := strings.Split(trim(line), "=")
			switch fields[0] {
			case "name":
				details.Name = fields[1]
			case "CN":
				details.CN = fields[1]
			case "C":
				details.Country = fields[1]
			case "ST":
				details.State = fields[1]
			case "L":
				details.City = fields[1]
			case "O":
				details.Organisation = fields[1]
			case "OU":
				details.OrganisationUnit = fields[1]
			case "emailAddress":
				details.Email = fields[1]
			case "LocalIP":
				details.LocalIP = fields[1]
			case "2FAName":
				details.TFAName = fields[1]
			default:
				if line != "" && !strings.Contains(line, "name") && !strings.Contains(line, "LocalIP") {
					logs.Warn(fmt.Sprintf("Undefined entry: %s", line))
				}
			}
		}
	}
	return details
}

func trim(s string) string {
	return strings.Trim(strings.Trim(s, "\r\n"), "\n")
}

// Le masque provient du serveur actif, y compris hors des deploiements Radio.
func staticClientConfig(ipText string, serverConf string) (string, error) {
	ip := net.ParseIP(ipText).To4()
	if ip == nil {
		return "", fmt.Errorf("invalid static IPv4: %s", ipText)
	}
	data, err := os.ReadFile(serverConf)
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 3 || fields[0] != "server" {
			continue
		}
		network := net.ParseIP(fields[1]).To4()
		maskIP := net.ParseIP(fields[2]).To4()
		if network == nil || maskIP == nil {
			break
		}
		mask := net.IPMask(maskIP)
		if ones, bits := mask.Size(); bits != 32 || ones < 1 || ones > 30 {
			break
		}
		subnet := net.IPNet{IP: network.Mask(mask), Mask: mask}
		serverIP := append(net.IP(nil), subnet.IP...)
		serverIP[3]++
		broadcast := append(net.IP(nil), subnet.IP...)
		for i := range broadcast {
			broadcast[i] |= ^mask[i]
		}
		if !subnet.Contains(ip) || ip.Equal(subnet.IP) || ip.Equal(serverIP) || ip.Equal(broadcast) {
			return "", fmt.Errorf("static IP %s is unavailable in %s", ipText, subnet.String())
		}
		return fmt.Sprintf("ifconfig-push %s %s\n", ip.String(), maskIP.String()), nil
	}
	return "", fmt.Errorf("server network not found in %s", serverConf)
}

func runVPNScript(script string, args []string, env []string) error {
	cmd := exec.Command("/bin/bash", append([]string{filepath.Join("/opt/scripts", script)}, args...)...)
	cmd.Dir = state.GlobalCfg.OVConfigPath
	cmd.Env = append(os.Environ(), env...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %w\n%s", script, err, output)
	}
	return nil
}

func CreateCertificate(name string, staticip string, passphrase string, expiredays string, email string, country string, province string, city string, org string, orgunit string, tfaname string, tfaissuer string) error {
	if !regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.@-]*$`).MatchString(name) {
		return fmt.Errorf("invalid certificate name")
	}
	subnet, err := models.RadioNetwork()
	if err != nil {
		return err
	}
	if subnet != nil && staticip == "" {
		return fmt.Errorf("a fixed IPv4 is required for Radio")
	}
	var ccd string
	if staticip != "" {
		ccd, err = staticClientConfig(staticip, filepath.Join(state.GlobalCfg.OVConfigPath, "server.conf"))
		if err != nil {
			return err
		}
	}
	certs, err := ReadCerts(filepath.Join(state.GlobalCfg.OVConfigPath, "pki/index.txt"))
	if err != nil {
		return err
	}
	for _, cert := range certs {
		if cert.Details.Name == name || cert.Details.CN == name {
			return fmt.Errorf("a certificate already exists for %q", name)
		}
		if staticip != "" && cert.EntryType == "V" && cert.Details.LocalIP == staticip {
			return fmt.Errorf("static IP %s is already assigned", staticip)
		}
	}
	if staticip == "" {
		staticip = "dynamic.pool"
	}
	env := []string{"KEY_NAME=" + name, "TFA_NAME=" + tfaname, "TFA_ISSUER=" + tfaissuer,
		"EASYRSA_CERT_EXPIRE=" + expiredays, "EASYRSA_REQ_EMAIL=" + email,
		"EASYRSA_REQ_COUNTRY=" + country, "EASYRSA_REQ_PROVINCE=" + province,
		"EASYRSA_REQ_CITY=" + city, "EASYRSA_REQ_ORG=" + org, "EASYRSA_REQ_OU=" + orgunit}
	if err := runVPNScript("genclient.sh", []string{name, staticip, passphrase}, env); err != nil {
		return err
	}
	if ccd != "" {
		path := filepath.Join(state.GlobalCfg.OVConfigPath, "staticclients", name)
		if err := os.WriteFile(path, []byte(ccd), 0644); err != nil {
			return err
		}
		// Le service UI a un umask prive ; nobody doit toutefois lire le CCD.
		return os.Chmod(path, 0644)
	}
	return nil
}

func RevokeCertificate(name string, serial string, tfaname string) error {
	return runVPNScript("revoke.sh", []string{name, serial}, []string{"TFA_NAME=" + tfaname})
}

func Restart() error {
	return runVPNScript("restart.sh", []string{"openvpn-server"}, nil)
}

func BurnCertificate(name string, serial string, tfaname string) error {
	return runVPNScript("rmcert.sh", []string{name, serial}, []string{"TFA_NAME=" + tfaname})
}

func RenewCertificate(name string, localip string, serial string, tfaname string) error {
	return runVPNScript("renew.sh", []string{name, localip, serial}, []string{"TFA_NAME=" + tfaname})
}
