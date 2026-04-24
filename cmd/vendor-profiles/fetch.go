package main

import (
	"fmt"
	"io"
	"net/http"
)

type Fetcher interface {
	Fetch(repo, ref, source string) ([]byte, error)
}

type HTTPFetcher struct{}

func (f *HTTPFetcher) Fetch(repo, ref, source string) ([]byte, error) {
	url := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s", repo, ref, source)
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("GET %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET %s: status %d", url, resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}
