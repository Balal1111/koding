package main

import (
	"flag"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"time"

	"github.com/koding/klient/Godeps/_workspace/src/github.com/koding/tunnel"
	"github.com/koding/klient/app"
	"github.com/koding/klient/fix"
	"github.com/koding/klient/protocol"
	"github.com/koding/klient/registration"
	klienttunnel "github.com/koding/klient/tunnel"
)

var (
	flagIP          = flag.String("ip", "", "Change public ip")
	flagPort        = flag.Int("port", 56789, "Change running port")
	flagVersion     = flag.Bool("version", false, "Show version and exit")
	flagEnvironment = flag.String("env", protocol.Environment, "Change environment")
	flagRegion      = flag.String("region", protocol.Region, "Change region")
	flagRegisterURL = flag.String("register-url", "", "Change register URL to kontrol")
	flagDebug       = flag.Bool("debug", false, "Debug mode")
	flagScreenrc    = flag.String("screenrc", "/opt/koding/etc/screenrc", "Default screenrc path")
	flagDBPath      = flag.String("dbpath", "", "Bolt DB database path. Must be absolute)")

	// Registration flags
	flagKiteHome   = flag.String("kite-home", "~/.kite/", "Change kite home path")
	flagUsername   = flag.String("username", "", "Username to be registered to Kontrol")
	flagToken      = flag.String("token", "", "Token to be passed to Kontrol to register")
	flagRegister   = flag.Bool("register", false, "Register to Kontrol with your Koding Password")
	flagKontrolURL = flag.String("kontrol-url", "",
		"Change kontrol URL to be used for registration")

	// update parameters
	flagUpdateInterval = flag.Duration("update-interval", time.Minute*5,
		"Change interval for checking for new updates")
	flagUpdateURL = flag.String("update-url",
		"https://s3.amazonaws.com/koding-klient/"+protocol.Environment+"/latest-version.txt",
		"Change update endpoint for latest version")

	// Tunnel flags
	flagTunnelServerAddr = flag.String("tunnel-server", "", "Tunnel server address")
	flagTunnelLocalAddr  = flag.String("tunnel-local", "", "Address of local server to be tunneled (optional)")
)

func main() {
	// Call realMain instead of doing the work here so we can use
	// `defer` statements within the function and have them work properly.
	// (defers aren't called with os.Exit)
	os.Exit(realMain())
}

func realMain() int {
	flag.Parse()
	if *flagVersion {
		fmt.Println(protocol.Version)
		return 0
	}

	if *flagRegister {
		if err := registration.Register(*flagKontrolURL, *flagKiteHome, *flagUsername, *flagToken); err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			return 1
		}
		return 0
	}

	dbPath := ""
	u, err := user.Current()
	if err == nil {
		dbPath = filepath.Join(u.HomeDir, "/.config/koding/klient.bolt")
	}

	if *flagDBPath != "" {
		dbPath = *flagDBPath
	}

	conf := &app.KlientConfig{
		Name:           protocol.Name,
		Version:        protocol.Version,
		IP:             *flagIP,
		Port:           *flagPort,
		Environment:    *flagEnvironment,
		Region:         *flagRegion,
		RegisterURL:    *flagRegisterURL,
		KontrolURL:     *flagKontrolURL,
		Debug:          *flagDebug,
		UpdateInterval: *flagUpdateInterval,
		UpdateURL:      *flagUpdateURL,
		ScreenrcPath:   *flagScreenrc,
		DBPath:         dbPath,
	}

	a := app.NewKlient(conf)
	defer a.Close()

	// Change tunnel server based on environment
	tunnelServerAddr := *flagTunnelServerAddr
	if tunnelServerAddr == "" {
		switch protocol.Environment {
		case "development":
			tunnelServerAddr = "devtunnelproxy.koding.com"
		case "production":
			tunnelServerAddr = "tunnelproxy.koding.com"
		}
	}

	// Open Pandora's box
	go klienttunnel.Start(a.Kite(), &tunnel.ClientConfig{
		ServerAddr: tunnelServerAddr,
		LocalAddr:  *flagTunnelLocalAddr,
		Debug:      *flagDebug,
	})

	// run inital fix commands
	if err := fix.Run(u.Username); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
	}

	// Run Forrest, Run!
	a.Run()

	return 0
}
