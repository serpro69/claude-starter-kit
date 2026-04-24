package main

import (
	"fmt"
	"io"
	"net/http"
	"time"
)

type Fetcher interface {
	Fetch(repo, ref, source string) ([]byte, error)
}

var _ Fetcher = (*HTTPFetcher)(nil)

type HTTPFetcher struct {
	Client *http.Client
}

func (f *HTTPFetcher) Fetch(repo, ref, source string) ([]byte, error) {
	client := f.Client
	if client == nil {
		client = &http.Client{Timeout: 30 * time.Second}
	}

	url := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s", repo, ref, source)
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("GET %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET %s: status %d", url, resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}
