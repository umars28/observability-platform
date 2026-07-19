// Package client calls demo-blog-web with a trace-propagating HTTP client.
package client

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

type BlogPost struct {
	ProductID string `json:"product_id"`
	Title     string `json:"title"`
	Excerpt   string `json:"excerpt"`
}

type BlogClient struct {
	baseURL string
	http    *http.Client
}

func NewBlogClient(baseURL string) *BlogClient {
	return &BlogClient{
		baseURL: baseURL,
		http: &http.Client{
			Timeout:   3 * time.Second,
			Transport: otelhttp.NewTransport(http.DefaultTransport),
		},
	}
}

// PostsFor fetches the blog posts about a product. Returns an empty slice on 404.
func (c *BlogClient) PostsFor(ctx context.Context, productID string) ([]BlogPost, error) {
	url := fmt.Sprintf("%s/posts/%s", c.baseURL, productID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return []BlogPost{}, nil
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("blog service returned %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var posts []BlogPost
	if err := json.Unmarshal(body, &posts); err != nil {
		return nil, fmt.Errorf("decode blog response: %w", err)
	}
	return posts, nil
}
