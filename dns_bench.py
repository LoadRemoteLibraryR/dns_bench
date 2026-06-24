#!/usr/bin/env python3
"""DNS benchmark.

Times A-record lookups across a list of public resolvers and renders a
live table that stays sorted by response time as each result comes in.

Requires dnspython:  pip install dnspython
"""

import socket
import sys
import time

import dns.exception
import dns.resolver

DEFAULT_HOST = "www.google.com"

SERVERS = {
    "OpenDNS_1": "208.67.222.222",
    "OpenDNS_2": "208.67.220.220",
    "L3_1": "209.244.0.3",
    "L3_2": "209.244.0.4",
    "Verisign": "64.6.64.6",
    "Google_1": "8.8.8.8",
    "Google_2": "8.8.4.4",
    "Quad9_1": "9.9.9.9",
    "CloudFlare": "1.1.1.1",
    "Quad9_2": "149.112.112.112",
    "DNSINC_1": "216.146.35.35",
    "DNSINC_2": "216.146.36.36",
    "CensurFriDNS": "89.233.43.71",
    "DNSWatch_1": "84.200.69.80",
    "DNSWatch_2": "84.200.70.40",
    "Hurricane Electric": "74.82.42.42",
    "OpenNIC": "94.247.43.254",
    "DNS4EU Protective": "86.54.11.1",
    "DNS4EU Child": "86.54.11.12",
    "DNS4EU Adblock": "86.54.11.13",
    "DNS4EU Unfiltered": "86.54.11.100",
}


def parse_args(argv):
    """Return the hostname to look up, or print help and exit."""
    if argv and argv[0] == "--help":
        print(f"\nUsage: {sys.argv[0]} [lookup_hostname]")
        print("If no hostname is provided www.google.com will be used\n")
        sys.exit(0)
    return argv[0] if argv else DEFAULT_HOST


def query_server(host, ip, timeout=2):
    """Time a single A-record lookup against one nameserver.

    Returns elapsed seconds, or raises a DNS/OS exception on failure.
    """
    resolver = dns.resolver.Resolver(configure=False)
    resolver.nameservers = [ip]
    resolver.timeout = timeout      # per-request timeout
    resolver.lifetime = timeout     # total time budget (covers the retry)

    start = time.perf_counter()
    resolver.resolve(host, "A")
    return time.perf_counter() - start


class LiveTable:
    """Reprints a time-sorted table in place each time a row is added."""

    def __init__(self, host):
        self.host = host
        self.rows = []          # list of (name, ip, elapsed)
        self._prev_lines = 0

    def add(self, name, ip, elapsed):
        self.rows.append((name, ip, elapsed))
        self._render()

    def _render(self):
        ordered = sorted(self.rows, key=lambda r: r[2])

        out = f"\nTiming lookups for {self.host}\n\n"
        out += f"{'Server':<20} {'IP':<15} {'Time':>4}\n"
        out += "-" * 45 + "\n"
        for name, ip, elapsed in ordered:
            out += f"{name:<20} {ip:<15} {elapsed:.5f}\n"

        # Move the cursor up over the previous render and clear it so the
        # table refreshes in place instead of scrolling.
        if self._prev_lines:
            sys.stdout.write(f"\033[{self._prev_lines}A\033[J")
        sys.stdout.write(out)
        sys.stdout.flush()
        self._prev_lines = out.count("\n")


def main():
    host = parse_args(sys.argv[1:])
    table = LiveTable(host)
    errors = []

    # OS default resolver
    try:
        start = time.perf_counter()
        socket.gethostbyname(host)
        table.add("OS_Default", "local", time.perf_counter() - start)
    except OSError as exc:
        errors.append(f"{'OS_Default':<10} {'local':<15} failed: {exc}")

    for name, ip in SERVERS.items():
        try:
            elapsed = query_server(host, ip)
        except (dns.exception.DNSException, OSError) as exc:
            msg = str(exc) or exc.__class__.__name__
            errors.append(f"{name:<10} {ip:<15} failed: {msg}")
            continue
        table.add(name, ip, elapsed)

    print()
    for err in errors:
        print(err)
    print()


if __name__ == "__main__":
    main()
