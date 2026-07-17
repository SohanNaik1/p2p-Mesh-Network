package main

import (
	"fmt"

	backend "p2p_server" // e.g., if go.mod says "module flux", put "flux" here
)

func main() {
	fmt.Println("💻 Starting Native PC Backend Server...")
	backend.StartServer()
}
