package routers

import (
	"github.com/beego/beego/v2/server/web"
)

func init() {

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISessionController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISessionController"],
			web.ControllerComments{
				Method:           "Get",
				Router:           `/`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISessionController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISessionController"],
			web.ControllerComments{
				Method:           "Kill",
				Router:           `/`,
				AllowHTTPMethods: []string{"delete"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISignalController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISignalController"],
			web.ControllerComments{
				Method:           "Send",
				Router:           `/`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISysloadController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:APISysloadController"],
			web.ControllerComments{
				Method:           "Get",
				Router:           `/`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Download",
				Router:           `/certificates/:key`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "DisplayImage",
				Router:           `/displayimage/:imageName`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Get",
				Router:           `/certificates`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Post",
				Router:           `/certificates`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Revoke",
				Router:           `/certificates/revoke/:key/:serial/:tfaname`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Restart",
				Router:           `/certificates/restart`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Burn",
				Router:           `/certificates/burn/:key/:serial/:tfaname`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:CertificatesController"],
			web.ControllerComments{
				Method:           "Renew",
				Router:           `/certificates/renew/:key/:localip/:serial/:tfaname`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:DangerController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:DangerController"],
			web.ControllerComments{
				Method:           "DeletePKI",
				Router:           `/pki/delete/:key`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:DangerController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:DangerController"],
			web.ControllerComments{
				Method:           "InitPKI",
				Router:           `/pki/init/:key`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:DangerController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:DangerController"],
			web.ControllerComments{
				Method:           "RestartContainer",
				Router:           `/container/restart/:key`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVConfigController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVConfigController"],
			web.ControllerComments{
				Method:           "Edit",
				Router:           `/ov/config/edit`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVConfigController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVConfigController"],
			web.ControllerComments{
				Method:           "Post",
				Router:           `/ov/config`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVConfigController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVConfigController"],
			web.ControllerComments{
				Method:           "Get",
				Router:           `/ov/config`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVClientConfigController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVClientConfigController"],
			web.ControllerComments{
				Method:           "Edit",
				Router:           `/ov/clientconfig/edit`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVClientConfigController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVClientConfigController"],
			web.ControllerComments{
				Method:           "Post",
				Router:           `/ov/clientconfig`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVClientConfigController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:OVClientConfigController"],
			web.ControllerComments{
				Method:           "Get",
				Router:           `/ov/clientconfig`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:ProfileController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:ProfileController"],
			web.ControllerComments{
				Method:           "Create",
				Router:           `/profile/create`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:ProfileController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:ProfileController"],
			web.ControllerComments{
				Method:           "DeleteUser",
				Router:           `/profile/delete/:key`,
				AllowHTTPMethods: []string{"get"},
				Params:           nil})

	web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:ProfileController"] =
		append(web.GlobalControllerRouter["github.com/SmallTech2/radio-vpn/controllers:ProfileController"],
			web.ControllerComments{
				Method:           "EditUser",
				Router:           `/profile/edit/:key`,
				AllowHTTPMethods: []string{"post"},
				Params:           nil})
}
