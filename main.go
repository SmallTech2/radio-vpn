package main

import (
	"flag"
	"fmt"
	"path/filepath"

	"github.com/beego/beego/v2/server/web"
	"github.com/SmallTech2/radio-vpn/lib"
	"github.com/SmallTech2/radio-vpn/models"
	"github.com/SmallTech2/radio-vpn/routers"
	"github.com/SmallTech2/radio-vpn/state"
)

func main() {
	configDir := flag.String("config", "conf", "Path to config dir")
	initializeOnly := flag.Bool("initialize-only", false, "Initialize database and configuration without starting HTTP")
	flag.Parse()

	configFile := filepath.Join(*configDir, "app.conf")
	fmt.Println("Config file:", configFile)

	if err := web.LoadAppConfig("ini", configFile); err != nil {
		panic(err)
	}

	models.InitDB()
	models.CreateDefaultUsers()
	defaultSettings, err := models.CreateDefaultSettings()
	if err != nil {
		panic(err)
	}

	models.CreateDefaultOVConfig(*configDir, defaultSettings.OVConfigPath, defaultSettings.MIAddress, defaultSettings.MINetwork)
	models.CreateDefaultOVClientConfig(*configDir, defaultSettings.OVConfigPath, defaultSettings.MIAddress, defaultSettings.MINetwork)
	models.CreateDefaultEasyRSAConfig(*configDir, defaultSettings.EasyRSAPath, defaultSettings.MIAddress, defaultSettings.MINetwork)
	state.GlobalCfg = *defaultSettings
	if *initializeOnly {
		return
	}

	routers.Init(*configDir)

	lib.AddFuncMaps()
	web.Run()
}
