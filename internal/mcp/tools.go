package mcp

import (
	"context"
	"fmt"

	gomcp "github.com/modelcontextprotocol/go-sdk/mcp"

	"github.com/myleshorton/wick/internal/engine"
	"github.com/myleshorton/wick/internal/extract"
	"github.com/myleshorton/wick/internal/fetch"
	"github.com/myleshorton/wick/internal/session"
)

// ── wick_fetch ──────────────────────────────────────────────────────

// FetchInput — url is required (no omitempty), format and respect_robots are optional.
type FetchInput struct {
	URL           string `json:"url"                      jsonschema:"The URL to fetch"`
	Format        string `json:"format,omitempty"          jsonschema:"Output format: markdown (default), html, or text. Markdown strips boilerplate and returns clean LLM-friendly content."`
	RespectRobots *bool  `json:"respect_robots,omitempty"  jsonschema:"Whether to respect robots.txt (default true)"`
}

type FetchOutput struct {
	Content    string `json:"content"              jsonschema:"The extracted page content"`
	Title      string `json:"title,omitempty"      jsonschema:"The page title if detected"`
	URL        string `json:"url"                  jsonschema:"The requested URL"`
	StatusCode int    `json:"status_code"          jsonschema:"HTTP status code (0 if blocked by robots.txt)"`
	TimingMs   int64  `json:"timing_ms"            jsonschema:"Request duration in milliseconds"`
}

// ── wick_search ─────────────────────────────────────────────────────

type SearchInput struct {
	Query      string `json:"query"                jsonschema:"Search query"`
	NumResults int    `json:"num_results,omitempty" jsonschema:"Number of search results to return (default 5)"`
}

type SearchOutput struct {
	Message string `json:"message" jsonschema:"Status message"`
}

// ── wick_session ────────────────────────────────────────────────────

type SessionInput struct {
	Action string `json:"action" jsonschema:"Session action: 'clear' removes all cookies and cache"`
}

type SessionOutput struct {
	Message string `json:"message" jsonschema:"Result message"`
}

// ── registration ────────────────────────────────────────────────────

func registerTools(server *gomcp.Server, fetcher *fetch.Fetcher, eng *engine.Engine) {
	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "wick_fetch",
		Description: "Fetch a web page using Chrome's network stack with browser-grade TLS fingerprinting. Returns clean, LLM-friendly content extracted from the page. Succeeds on sites that block standard HTTP clients (Cloudflare, Akamai, etc.).",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, input FetchInput) (*gomcp.CallToolResult, FetchOutput, error) {
		format := extract.FormatMarkdown
		if input.Format != "" {
			format = extract.Format(input.Format)
		}

		respectRobots := true
		if input.RespectRobots != nil {
			respectRobots = *input.RespectRobots
		}

		result, err := fetcher.Fetch(fetch.Request{
			URL:           input.URL,
			Format:        format,
			RespectRobots: respectRobots,
			Ctx:           ctx,
		})
		if err != nil {
			return &gomcp.CallToolResult{
				IsError: true,
				Content: []gomcp.Content{
					&gomcp.TextContent{Text: fmt.Sprintf("Fetch failed: %s", err)},
				},
			}, FetchOutput{}, nil
		}

		return &gomcp.CallToolResult{
			Content: []gomcp.Content{
				&gomcp.TextContent{Text: result.Content},
			},
		}, FetchOutput{
			Content:    result.Content,
			Title:      result.Title,
			URL:        result.URL,
			StatusCode: result.StatusCode,
			TimingMs:   result.TimingMs,
		}, nil
	})

	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "wick_search",
		Description: "Search the web and optionally fetch top results with browser-grade access. Note: basic implementation in v0.1.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, input SearchInput) (*gomcp.CallToolResult, SearchOutput, error) {
		return &gomcp.CallToolResult{
			Content: []gomcp.Content{
				&gomcp.TextContent{Text: "Web search is not yet implemented in v0.1. Use wick_fetch with a specific URL instead."},
			},
		}, SearchOutput{
			Message: "Web search is not yet implemented in v0.1.",
		}, nil
	})

	gomcp.AddTool(server, &gomcp.Tool{
		Name:        "wick_session",
		Description: "Manage persistent browser sessions. Clear cookies and session data to start fresh.",
	}, func(ctx context.Context, req *gomcp.CallToolRequest, input SessionInput) (*gomcp.CallToolResult, SessionOutput, error) {
		switch input.Action {
		case "clear":
			if err := session.ClearSession(); err != nil {
				return &gomcp.CallToolResult{
					IsError: true,
					Content: []gomcp.Content{
						&gomcp.TextContent{Text: fmt.Sprintf("Failed to clear session: %s", err)},
					},
				}, SessionOutput{}, nil
			}
			return &gomcp.CallToolResult{
				Content: []gomcp.Content{
					&gomcp.TextContent{Text: "Session cleared. Cookies and cache data have been removed. Restart wick for changes to take full effect."},
				},
			}, SessionOutput{
				Message: "Session cleared successfully.",
			}, nil
		default:
			return &gomcp.CallToolResult{
				IsError: true,
				Content: []gomcp.Content{
					&gomcp.TextContent{Text: fmt.Sprintf("Unknown action: %q. Supported: clear", input.Action)},
				},
			}, SessionOutput{}, nil
		}
	})
}
