// Package catalog is an in-memory product store with intentional slow paths
// to make the demo interesting (traces, hotspots, error rate).
package catalog

import (
	"context"
	"errors"
	"math/rand"
	"sync"
	"time"
)

type Product struct {
	ID    string  `json:"id"`
	Name  string  `json:"name"`
	Price float64 `json:"price"`
	Stock int     `json:"stock"`
}

var ErrNotFound = errors.New("product not found")

type Store struct {
	mu   sync.RWMutex
	data map[string]Product
}

func NewStore() *Store {
	s := &Store{data: make(map[string]Product)}
	// Seed
	for _, p := range []Product{
		{"p-1", "Mechanical Keyboard", 129.00, 12},
		{"p-2", "Ergonomic Mouse", 45.00, 30},
		{"p-3", "USB-C Hub", 39.00, 55},
		{"p-4", "Standing Desk Mat", 79.00, 8},
		{"p-5", "Noise-Cancelling Headphones", 249.00, 0},
	} {
		s.data[p.ID] = p
	}
	return s
}

// List returns all products. Simulates variable DB latency.
func (s *Store) List(ctx context.Context) ([]Product, error) {
	simulateLatency(20, 80)
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Product, 0, len(s.data))
	for _, p := range s.data {
		out = append(out, p)
	}
	return out, nil
}

// Get returns a product by ID. 5% chance of a synthetic slow query
// (illustrates a p99 latency spike + Pyroscope hotspot).
func (s *Store) Get(ctx context.Context, id string) (Product, error) {
	if rand.Intn(100) < 5 {
		burnCPU(150 * time.Millisecond) // synthetic hotspot
	}
	simulateLatency(10, 40)
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.data[id]
	if !ok {
		return Product{}, ErrNotFound
	}
	return p, nil
}

// Order decrements stock. 3% chance of a synthetic failure to give the alerts
// something to alert on.
func (s *Store) Order(ctx context.Context, id string, qty int) error {
	if rand.Intn(100) < 3 {
		return errors.New("payment provider timed out")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.data[id]
	if !ok {
		return ErrNotFound
	}
	if p.Stock < qty {
		return errors.New("insufficient stock")
	}
	p.Stock -= qty
	s.data[id] = p
	return nil
}

func simulateLatency(minMs, maxMs int) {
	time.Sleep(time.Duration(minMs+rand.Intn(maxMs-minMs)) * time.Millisecond)
}

// burnCPU keeps a core busy for the given duration — surfaces in CPU profiles.
func burnCPU(d time.Duration) {
	deadline := time.Now().Add(d)
	x := 0
	for time.Now().Before(deadline) {
		x = (x*1664525 + 1013904223) & 0xFFFFFFFF
	}
	_ = x
}
