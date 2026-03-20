package extract

import (
	"bytes"
	"io"
	"net/url"

	readability "codeberg.org/readeck/go-readability/v2"
)

// ReadabilityResult holds content extracted by the readability algorithm.
type ReadabilityResult struct {
	Title   string
	Byline  string
	Excerpt string
	HTML    string
	Text    string
}

// ExtractReadable runs the readability algorithm (Mozilla-compatible) to
// strip navigation, ads, and boilerplate from raw HTML.
func ExtractReadable(body io.Reader, pageURL *url.URL) (*ReadabilityResult, error) {
	article, err := readability.FromReader(body, pageURL)
	if err != nil {
		return nil, err
	}

	var htmlBuf bytes.Buffer
	if err := article.RenderHTML(&htmlBuf); err != nil {
		return nil, err
	}

	var textBuf bytes.Buffer
	if err := article.RenderText(&textBuf); err != nil {
		return nil, err
	}

	return &ReadabilityResult{
		Title:   article.Title(),
		Byline:  article.Byline(),
		Excerpt: article.Excerpt(),
		HTML:    htmlBuf.String(),
		Text:    textBuf.String(),
	}, nil
}
