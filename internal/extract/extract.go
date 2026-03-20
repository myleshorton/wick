package extract

import (
	"fmt"
	"io"
	"net/url"
	"strings"
)

// Format controls how fetched content is returned.
type Format string

const (
	FormatMarkdown Format = "markdown"
	FormatHTML     Format = "html"
	FormatText     Format = "text"
)

// Result is the extracted content plus metadata.
type Result struct {
	Content string
	Title   string
}

// Extract runs the full content extraction pipeline:
//
//	raw HTML → readability (strip boilerplate) → format conversion
func Extract(body io.Reader, pageURL *url.URL, format Format) (*Result, error) {
	switch format {
	case FormatHTML:
		raw, err := io.ReadAll(body)
		if err != nil {
			return nil, err
		}
		return &Result{Content: string(raw)}, nil

	case FormatText:
		readable, err := ExtractReadable(body, pageURL)
		if err != nil {
			return nil, fmt.Errorf("readability extraction failed: %w", err)
		}
		return &Result{
			Content: readable.Text,
			Title:   readable.Title,
		}, nil

	case FormatMarkdown, "": // default to markdown
		readable, err := ExtractReadable(body, pageURL)
		if err != nil {
			return nil, fmt.Errorf("readability extraction failed: %w", err)
		}

		domain := pageURL.Scheme + "://" + pageURL.Host
		md, err := ToMarkdown(readable.HTML, domain)
		if err != nil {
			return nil, fmt.Errorf("markdown conversion failed: %w", err)
		}

		if readable.Title != "" {
			md = "# " + readable.Title + "\n\n" + md
		}
		return &Result{
			Content: strings.TrimSpace(md),
			Title:   readable.Title,
		}, nil

	default:
		return nil, fmt.Errorf("unsupported format: %s", format)
	}
}
