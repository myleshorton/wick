package extract

import (
	"github.com/JohannesKaufmann/html-to-markdown/v2/converter"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/base"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/commonmark"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/table"
)

// ToMarkdown converts cleaned HTML to LLM-friendly markdown.
// If domain is non-empty, relative URLs are resolved against it.
func ToMarkdown(html string, domain string) (string, error) {
	conv := converter.NewConverter(
		converter.WithPlugins(
			base.NewBasePlugin(),
			commonmark.NewCommonmarkPlugin(),
			table.NewTablePlugin(
				table.WithHeaderPromotion(true),
			),
		),
	)

	var opts []converter.ConvertOptionFunc
	if domain != "" {
		opts = append(opts, converter.WithDomain(domain))
	}

	return conv.ConvertString(html, opts...)
}
