package extract

import (
	"net/url"
	"strings"
	"testing"
)

const testHTML = `<!DOCTYPE html>
<html>
<head><title>Test Article</title></head>
<body>
<nav><a href="/">Home</a> | <a href="/about">About</a></nav>
<article>
<h1>Test Article Title</h1>
<p>This is a test paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
<p>Another paragraph with a <a href="https://example.com">link</a>.</p>
<table>
<tr><th>Name</th><th>Value</th></tr>
<tr><td>foo</td><td>bar</td></tr>
<tr><td>baz</td><td>qux</td></tr>
</table>
<ul>
<li>Item one</li>
<li>Item two</li>
<li>Item three</li>
</ul>
</article>
<footer>Copyright 2026</footer>
</body>
</html>`

func TestToMarkdown(t *testing.T) {
	md, err := ToMarkdown("<h1>Hello</h1><p>World</p>", "")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(md, "Hello") {
		t.Errorf("expected 'Hello' in markdown output, got: %s", md)
	}
	if !strings.Contains(md, "World") {
		t.Errorf("expected 'World' in markdown output, got: %s", md)
	}
}

func TestToMarkdownWithTable(t *testing.T) {
	html := `<table>
<tr><th>A</th><th>B</th></tr>
<tr><td>1</td><td>2</td></tr>
</table>`
	md, err := ToMarkdown(html, "")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(md, "|") {
		t.Errorf("expected markdown table with pipes, got: %s", md)
	}
}

func TestToMarkdownWithDomain(t *testing.T) {
	html := `<a href="/path">link</a>`
	md, err := ToMarkdown(html, "https://example.com")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(md, "https://example.com/path") {
		t.Errorf("expected absolute URL, got: %s", md)
	}
}

func TestExtractReadable(t *testing.T) {
	pageURL, _ := url.Parse("https://example.com/article")
	result, err := ExtractReadable(strings.NewReader(testHTML), pageURL)
	if err != nil {
		t.Fatal(err)
	}
	if result.Title == "" {
		t.Error("expected non-empty title")
	}
	if result.HTML == "" {
		t.Error("expected non-empty HTML")
	}
	if result.Text == "" {
		t.Error("expected non-empty Text")
	}
}

func TestExtractMarkdown(t *testing.T) {
	pageURL, _ := url.Parse("https://example.com/article")
	result, err := Extract(strings.NewReader(testHTML), pageURL, FormatMarkdown)
	if err != nil {
		t.Fatal(err)
	}
	if result.Content == "" {
		t.Error("expected non-empty content")
	}
	if !strings.Contains(result.Content, "#") {
		t.Error("expected markdown headings")
	}
}

func TestExtractHTML(t *testing.T) {
	pageURL, _ := url.Parse("https://example.com/article")
	result, err := Extract(strings.NewReader(testHTML), pageURL, FormatHTML)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(result.Content, "<html>") {
		t.Error("expected raw HTML")
	}
}

func TestExtractText(t *testing.T) {
	pageURL, _ := url.Parse("https://example.com/article")
	result, err := Extract(strings.NewReader(testHTML), pageURL, FormatText)
	if err != nil {
		t.Fatal(err)
	}
	if result.Content == "" {
		t.Error("expected non-empty text content")
	}
	if strings.Contains(result.Content, "<") {
		t.Error("expected no HTML tags in text output")
	}
}
