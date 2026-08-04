#!/usr/bin/env python3
"""Ping every usable IP address in a CIDR range."""

from __future__ import annotations

import argparse
import ipaddress
import math
import platform
import subprocess
from concurrent.futures import ThreadPoolExecutor


RED = "\033[31m"
GREEN = "\033[32m"
RESET = "\033[0m"


def ping(ip_address: str, timeout: float = 1.0) -> bool:
    """Return True when *ip_address* replies to one ICMP echo request."""
    system = platform.system().lower()

    if system == "windows":
        command = ["ping", "-n", "1", "-w", str(math.ceil(timeout * 1000)), ip_address]
    elif system == "darwin":
        command = ["ping", "-c", "1", "-W", str(math.ceil(timeout * 1000)), ip_address]
    else:
        command = ["ping", "-c", "1", "-W", str(math.ceil(timeout)), ip_address]

    try:
        result = subprocess.run(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=timeout + 1,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False

    return result.returncode == 0


def scan_cidr(
    cidr: str, timeout: float = 1.0, workers: int = 64
) -> dict[str, list[str]]:
    """Return reachable and unreachable usable addresses in *cidr*."""
    network = ipaddress.ip_network(cidr, strict=False)
    addresses = [str(address) for address in network.hosts()]

    with ThreadPoolExecutor(max_workers=workers) as executor:
        replies = executor.map(lambda address: ping(address, timeout), addresses)

    result: dict[str, list[str]] = {"reachable": [], "unreachable": []}
    for address, replied in zip(addresses, replies):
        key = "reachable" if replied else "unreachable"
        result[key].append(address)

    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ping the usable IP addresses in an IPv4 or IPv6 CIDR range."
    )
    parser.add_argument("cidr", help="CIDR to scan, for example 192.168.1.0/24")
    parser.add_argument(
        "--timeout",
        type=float,
        default=1.0,
        help="timeout for each ping in seconds (default: 1)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=64,
        help="maximum number of concurrent pings (default: 64)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.timeout <= 0:
        raise SystemExit("--timeout must be greater than zero")
    if args.workers <= 0:
        raise SystemExit("--workers must be greater than zero")

    try:
        result = scan_cidr(args.cidr, args.timeout, args.workers)
    except ValueError as error:
        raise SystemExit(f"Invalid CIDR: {error}") from error

    reachable = set(result["reachable"])
    addresses = sorted(
        result["reachable"] + result["unreachable"], key=ipaddress.ip_address
    )
    for address in addresses:
        if address in reachable:
            print(f"{address} - {RED}Busy{RESET}")
        else:
            print(f"{address} - {GREEN}Available{RESET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
