#!/usr/bin/env python3
"""Ping every usable IP address in a CIDR range."""

from __future__ import annotations

import argparse
import ipaddress
import platform
import subprocess
from concurrent.futures import ThreadPoolExecutor


RED = "\033[31m"
GREEN = "\033[32m"
RESET = "\033[0m"
PING_COUNT = 2
PING_TIMEOUT_SECONDS = 2
MAX_WORKERS = 64


def ping(ip_address: str) -> bool:
    """Return True when *ip_address* replies to an ICMP echo request."""
    system = platform.system().lower()

    if system == "windows":
        command = [
            "ping",
            "-4",
            "-n",
            str(PING_COUNT),
            "-w",
            str(PING_TIMEOUT_SECONDS * 1000),
            ip_address,
        ]
    elif system == "darwin":
        command = [
            "ping",
            "-c",
            str(PING_COUNT),
            "-W",
            str(PING_TIMEOUT_SECONDS * 1000),
            ip_address,
        ]
    else:
        command = [
            "ping",
            "-4",
            "-c",
            str(PING_COUNT),
            "-W",
            str(PING_TIMEOUT_SECONDS),
            ip_address,
        ]

    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=(PING_TIMEOUT_SECONDS * PING_COUNT) + 1,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False

    # Windows may return exit code 0 for ICMP errors such as "Destination host
    # unreachable". A genuine echo reply includes the packet's TTL.
    return result.returncode == 0 and b"ttl=" in result.stdout.lower()


def scan_cidr(cidr: str) -> dict[str, list[str]]:
    """Return reachable and unreachable usable addresses in *cidr*."""
    network = ipaddress.ip_network(cidr, strict=False)
    if network.version != 4:
        raise ValueError("only IPv4 CIDR ranges are supported")
    addresses = [str(address) for address in network.hosts()]

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        replies = executor.map(ping, addresses)

    result: dict[str, list[str]] = {"reachable": [], "unreachable": []}
    for address, replied in zip(addresses, replies):
        key = "reachable" if replied else "unreachable"
        result[key].append(address)

    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ping the usable IP addresses in an IPv4 CIDR range."
    )
    parser.add_argument("cidr", help="CIDR to scan, for example 192.168.1.0/24")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        result = scan_cidr(args.cidr)
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
