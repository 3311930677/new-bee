package online

import (
	"fmt"
	"io"
	"sort"
	"strconv"
	"sync"
	"time"
)

var latencyBuckets = [...]float64{0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 5, 15}

type requestMetricKey struct{ route, method, statusClass string }
type requestMetric struct {
	count   uint64
	seconds float64
	buckets [len(latencyBuckets)]uint64
}
type runtimeMetrics struct {
	mu       sync.Mutex
	requests map[requestMetricKey]requestMetric
	errors   map[string]uint64
}

func metricMethod(method string) string {
	switch method {
	case "GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "CONNECT", "TRACE":
		return method
	default:
		return "OTHER"
	}
}

func (m *runtimeMetrics) observeRequest(route, method string, status int, elapsed time.Duration) {
	// All non-matching user paths share one fixed label. Never label a metric
	// with the raw request URI, a character ID, an address or a supplied method.
	if route == "" {
		route = "unmatched"
	}
	class := "other"
	if status >= 100 && status < 600 {
		class = fmt.Sprintf("%dxx", status/100)
	}
	key := requestMetricKey{route, metricMethod(method), class}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.requests == nil {
		m.requests = make(map[requestMetricKey]requestMetric)
	}
	sample := m.requests[key]
	sample.count++
	seconds := elapsed.Seconds()
	sample.seconds += seconds
	for index, bound := range latencyBuckets {
		if seconds <= bound {
			sample.buckets[index]++
		}
	}
	m.requests[key] = sample
}

func (m *runtimeMetrics) observeError(kind string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.errors == nil {
		m.errors = make(map[string]uint64)
	}
	if _, exists := m.errors[kind]; !exists && len(m.errors) >= 128 {
		kind = "other"
	}
	m.errors[kind]++
}

func (m *runtimeMetrics) write(w io.Writer) {
	m.mu.Lock()
	requests := make(map[requestMetricKey]requestMetric, len(m.requests))
	for key, value := range m.requests {
		requests[key] = value
	}
	errors := make(map[string]uint64, len(m.errors))
	for key, value := range m.errors {
		errors[key] = value
	}
	m.mu.Unlock()
	keys := make([]requestMetricKey, 0, len(requests))
	for key := range requests {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		a, b := keys[i], keys[j]
		if a.route != b.route {
			return a.route < b.route
		}
		if a.method != b.method {
			return a.method < b.method
		}
		return a.statusClass < b.statusClass
	})
	fmt.Fprintln(w, "# HELP yuanzheng_http_requests_total Number of completed requests by registered route template.")
	fmt.Fprintln(w, "# TYPE yuanzheng_http_requests_total counter")
	for _, key := range keys {
		value := requests[key]
		labels := "route=" + strconv.Quote(key.route) + ",method=" + strconv.Quote(key.method) + ",status_class=" + strconv.Quote(key.statusClass)
		fmt.Fprintf(w, "yuanzheng_http_requests_total{%s} %d\n", labels, value.count)
	}
	fmt.Fprintln(w, "# HELP yuanzheng_http_request_duration_seconds Wall-clock HTTP request duration in seconds.")
	fmt.Fprintln(w, "# TYPE yuanzheng_http_request_duration_seconds histogram")
	for _, key := range keys {
		value := requests[key]
		labels := "route=" + strconv.Quote(key.route) + ",method=" + strconv.Quote(key.method) + ",status_class=" + strconv.Quote(key.statusClass)
		for index, bound := range latencyBuckets {
			fmt.Fprintf(w, "yuanzheng_http_request_duration_seconds_bucket{%s,le=%q} %d\n", labels, strconv.FormatFloat(bound, 'g', -1, 64), value.buckets[index])
		}
		fmt.Fprintf(w, "yuanzheng_http_request_duration_seconds_bucket{%s,le=\"+Inf\"} %d\n", labels, value.count)
		fmt.Fprintf(w, "yuanzheng_http_request_duration_seconds_count{%s} %d\n", labels, value.count)
		fmt.Fprintf(w, "yuanzheng_http_request_duration_seconds_sum{%s} %g\n", labels, value.seconds)
	}
	fmt.Fprintln(w, "# HELP yuanzheng_internal_failures_total Internal failures classified without private error details.")
	fmt.Fprintln(w, "# TYPE yuanzheng_internal_failures_total counter")
	errorKeys := make([]string, 0, len(errors))
	for key := range errors {
		errorKeys = append(errorKeys, key)
	}
	sort.Strings(errorKeys)
	for _, key := range errorKeys {
		fmt.Fprintf(w, "yuanzheng_internal_failures_total{kind=%q} %d\n", key, errors[key])
	}
}
