#!/usr/bin/env python3
"""
send_firewall_syslog.py

Simulate firewall logs and send them to a syslog server.

"""
import argparse
import socket
import time
import random
import datetime
import ipaddress
import sys
import os

WELL_KNOWN_PORTS = [
    20, 21, 22, 23, 25, 53, 67, 68, 80, 110, 123, 137, 138, 139, 143, 161, 162,
    389, 443, 465, 587, 636, 993, 995, 1433, 1521, 2049, 3306, 3389, 5432, 5900, 8080, 8443
]

PRIVATE_NETS = [
    ipaddress.IPv4Network("10.0.0.0/8"),
    ipaddress.IPv4Network("172.16.0.0/12"),
    ipaddress.IPv4Network("192.168.0.0/16"),
    ipaddress.IPv4Network("127.0.0.0/8"),
    ipaddress.IPv4Network("169.254.0.0/16"),
    ipaddress.IPv4Network("224.0.0.0/3"),  # multicast & beyond
]




def is_public_ipv4(addr: str) -> bool:
    ip = ipaddress.IPv4Address(addr)
    for net in PRIVATE_NETS:
        if ip in net:
            return False
    return True


def random_public_ipv4() -> str:
    # pick until we get a public IPv4 address
    while True:
        octets = [str(random.randint(1, 254)) for _ in range(4)]
        ip = ".".join(octets)
        if is_public_ipv4(ip):
            return ip


def syslog_rfc3164_message(hostname: str, appname: str, pid: int, msg: str, pri: int = 14) -> str:
    # pri default 14 -> facility 1 (user-level), severity 6 (info) => 1*8+6=14
    timestamp = datetime.datetime.utcnow().strftime("%b %d %H:%M:%S")
    return f"<{pri}>{timestamp} {hostname} {appname}[{pid}]: {msg}"


def build_firewall_payload(src_ip: str,
                           src_port: int,
                           dst_ip: str,
                           dst_port: int,
                           proto: str,
                           action: str,
                           rule: str,
                           bytes_sent: int,
                           packets: int) -> str:
    # custom, compact firewall log format (adjust as desired)
    ts = datetime.datetime.utcnow().isoformat() + "Z"
    return (f"time={ts} action={action} proto={proto} "
            f"src={src_ip} spt={src_port} dst={dst_ip} dpt={dst_port} "
            f"bytes={bytes_sent} pkts={packets} rule={rule}")


def send_syslog_message(sock: socket.socket, server: str, port: int, message: bytes, proto: str):
    if proto == "udp":
        sock.sendto(message, (server, port))
    else:
        # for TCP, ensure socket is connected
        sock.sendall(message)


def main():
    parser = argparse.ArgumentParser(description="Send simulated firewall logs to a syslog server.")
    parser.add_argument("--server", "-s", required=True, help="Syslog server IP or hostname")
    parser.add_argument("--port", "-p", type=int, default=514, help="Syslog server port (default 514)")
    parser.add_argument("--proto", choices=["udp", "tcp"], default="udp", help="Transport protocol (default udp)")
    parser.add_argument("--count", "-c", type=int, default=0,
                        help="Number of messages to send. 0 = infinite (default 0)")
    parser.add_argument("--rate", "-r", type=float, default=0.2,
                        help="Seconds between messages (default 0.2s => 5 msgs/sec). Use 0 for as-fast-as-possible.")
    parser.add_argument("--src-ip", default="192.168.0.1", help="Source IP to use (default 192.168.0.1)")
    parser.add_argument("--well-known", nargs="*", type=int, default=WELL_KNOWN_PORTS,
                        help="List of destination ports to choose from (default common well-known ports)")
    parser.add_argument("--hostname", default="fw-simulator", help="hostname used in syslog header")
    parser.add_argument("--app", default="simfw", help="app name used in syslog header")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducible runs")
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    proto = args.proto.lower()
    server = args.server
    port = args.port

    # socket setup
    if proto == "udp":
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    else:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.connect((server, port))
        except Exception as e:
            print(f"Failed to connect to {server}:{port} via TCP: {e}", file=sys.stderr)
            sys.exit(2)

    pid = random.randint(1000, 65000)
    sent = 0

    try:
        while True:
            if args.count > 0 and sent >= args.count:
                break

            src_ip = args.src_ip
            src_port = random.randint(1024, 65535)

            dst_ip = random_public_ipv4()
            dst_port = random.choice(args.well_known) if args.well_known else random.randint(1, 1023)

            proto_name = random.choice(["TCP", "UDP", "ICMP"])
            action = random.choice(["ALLOW", "DENY"])
            rule = random.choice(["r-allow-web", "r-block-bot", "r-ssh", "r-dmz", "r-default-deny"])
            bytes_sent = random.randint(40, 15000)
            packets = random.randint(1, 50)

            payload = build_firewall_payload(
                src_ip=src_ip,
                src_port=src_port,
                dst_ip=dst_ip,
                dst_port=dst_port,
                proto=proto_name,
                action=action,
                rule=rule,
                bytes_sent=bytes_sent,
                packets=packets
            )

            syslog_msg = syslog_rfc3164_message(
                hostname=args.hostname,
                appname=args.app,
                pid=pid,
                msg=payload,
                pri=14
            )

            # syslog over TCP should be framed (octet counting) per RFC6587, but many collectors accept raw lines.
            if proto == "tcp":
                # add \n and send with length prefix (octet-counting)
                raw = (str(len(syslog_msg)) + " " + syslog_msg + "\n").encode("utf-8")
            else:
                raw = (syslog_msg + "\n").encode("utf-8")

            try:
                send_syslog_message(sock, server, port, raw, proto)
            except Exception as e:
                print(f"Failed to send message: {e}", file=sys.stderr)
                # continue or break depending on preference — continue for resilience
                time.sleep(1)

            sent += 1
            # print to console for visibility
            print(f"sent #{sent}: {syslog_msg}")

            if args.rate > 0:
                time.sleep(args.rate)
            # if rate==0 -> send as fast as possible

        server = args.server or os.getenv("VM_IP")
        if not server:
            print("No syslog server IP provided via --server or VM_IP env variable.")
            sys.exit(1)


    except KeyboardInterrupt:
        print("\nInterrupted by user, shutting down.")
    finally:
        sock.close()


if __name__ == "__main__":
    main()
