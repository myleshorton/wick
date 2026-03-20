package mcp

import (
	"context"

	gomcp "github.com/modelcontextprotocol/go-sdk/mcp"

	"github.com/myleshorton/wick/internal/engine"
	"github.com/myleshorton/wick/internal/fetch"
	"github.com/myleshorton/wick/pkg/version"
)

// Serve creates the MCP server, registers all tools, and blocks on stdio.
func Serve(ctx context.Context, eng *engine.Engine) error {
	server := gomcp.NewServer(
		&gomcp.Implementation{
			Name:    "wick",
			Version: version.Version,
		},
		nil,
	)

	fetcher := fetch.NewFetcher(eng)
	registerTools(server, fetcher, eng)

	return server.Run(ctx, &gomcp.StdioTransport{})
}
