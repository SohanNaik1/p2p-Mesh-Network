package backend

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gorilla/websocket"
	"github.com/hashicorp/mdns"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func handleConnection(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Println("❌ Error upgrading connection:", err)
		return
	}
	defer conn.Close()

	hostname, _ := os.Hostname()
	if hostname == "localhost" {
		hostname = "Flux-Android"
	}
	conn.WriteMessage(websocket.TextMessage, []byte("HANDSHAKE:"+hostname))

	var activeFile *os.File
	defer func() {
		if activeFile != nil {
			activeFile.Close()
		}
	}()

	for {
		messageType, p, err := conn.ReadMessage()
		if err != nil {
			break
		}

		if messageType == websocket.TextMessage {
			data := string(p)

			if strings.HasPrefix(data, "METADATA:") {
				fileName := strings.TrimPrefix(data, "METADATA:")
				fmt.Printf("📥 Receiving file: %s\n", fileName)

				// FIX: Safe path for both Android and PC
				savePath := filepath.Join(os.TempDir(), "received_"+fileName)
				activeFile, err = os.Create(savePath)
				if err != nil {
					fmt.Printf("❌ Failed to create file: %v\n", err)
				} else {
					fmt.Printf("📂 Saving to: %s\n", savePath)
				}

			} else if strings.HasPrefix(data, "REQUEST:") {
				// ... your existing request code ...
			}

		} else if messageType == websocket.BinaryMessage {
			if activeFile != nil {
				activeFile.Write(p)
			}
		}
	}
}

func getLocalIP() string {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return "127.0.0.1"
	}
	defer conn.Close()
	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String()
}

func StartServer() {
	hostname, err := os.Hostname()
	if err != nil || hostname == "localhost" {
		hostname = "Flux-Phone-" + fmt.Sprintf("%d", time.Now().Unix()%100)
	}

	realIP := getLocalIP()
	info := []string{"Flux P2P File Share"}

	// 🛑 CRITICAL FIX: Force the target hostname so it doesn't default to "localhost"
	targetHostname := hostname + ".local."

	service, err := mdns.NewMDNSService(
		hostname,                      // Instance name
		"_fluxshare._tcp",             // Service Type
		"local.",                      // Domain
		targetHostname,                // <--- PUT THIS HERE (No longer blank "")
		8080,                          // Port
		[]net.IP{net.ParseIP(realIP)}, // Force binding to the true Wi-Fi IP
		info,                          // TXT records
	)
	// ... rest of the code remains the same ...
	if err != nil {
		fmt.Printf("❌ Failed to create mDNS service: %v\n", err)
		return
	}

	server, err := mdns.NewServer(&mdns.Config{Zone: service})
	if err != nil {
		fmt.Printf("❌ Failed to start mDNS server: %v\n", err)
		return
	}
	defer server.Shutdown()

	http.HandleFunc("/ws", handleConnection)
	fmt.Printf("🚀 Go Backend Active!\n")
	fmt.Printf("📡 Broadcasting: %s over mDNS\n", hostname)
	fmt.Printf("🌐 Target IP Address: %s:8080\n", realIP)

	err = http.ListenAndServe("0.0.0.0:8080", nil)
	if err != nil {
		fmt.Printf("❌ HTTP Server crashed: %v\n", err)
	}
}
