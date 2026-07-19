#!/usr/bin/env python3
"""跨平台的生产运维命令包装器。

提供 status / logs / stop 三个固定子命令，避免直接调用 docker compose 时
需要记忆复杂参数。所有命令都通过 docker compose CLI 执行，不直接操作
Docker API。

用法：
    python scripts/production_ops.py --env-file .env status
    python scripts/production_ops.py --env-file .env logs --tail 200 api web
    python scripts/production_ops.py --env-file .env logs --follow --tail 200 api worker
    python scripts/production_ops.py --env-file .env stop

日志服务名仅允许：mysql、redis、migrate、api、worker、crawler、web
--tail 范围 1-10000。停止命令只移除容器和网络，不删除命名卷或镜像。
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ALLOWED_LOG_SERVICES = frozenset({
    "mysql", "redis", "migrate", "api", "worker", "crawler", "web"
})
MIN_TAIL = 1
MAX_TAIL = 10000


def die(msg: str, code: int = 2) -> None:
    print(f"✗ {msg}", file=sys.stderr)
    sys.exit(code)


def info(msg: str) -> None:
    print(f"• {msg}", file=sys.stderr)


def find_compose_file(project_dir: Path) -> Path:
    compose = project_dir / "docker-compose.yml"
    if not compose.is_file():
        die(f"未找到 {compose}")
    return compose


def docker_available() -> bool:
    try:
        subprocess.run(
            ["docker", "compose", "version"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except FileNotFoundError:
        return False


def build_base_cmd(compose_path: Path, env_file: Path | None) -> list[str]:
    cmd = ["docker", "compose", "-f", str(compose_path)]
    if env_file and env_file.is_file():
        cmd.extend(["--env-file", str(env_file)])
    # 兼容 Compose 项目名（防止误用宿主残留）
    cmd.extend(["-p", "xianyu-assistant"])
    return cmd


def cmd_status(args: argparse.Namespace, project_dir: Path) -> int:
    compose = find_compose_file(project_dir)
    if not docker_available():
        die("未检测到 docker compose 命令，请先安装 Docker")
    env_file = Path(args.env_file) if args.env_file else None
    cmd = build_base_cmd(compose, env_file) + ["ps", "--all"]
    return subprocess.call(cmd)


def cmd_logs(args: argparse.Namespace, project_dir: Path) -> int:
    compose = find_compose_file(project_dir)
    if not docker_available():
        die("未检测到 docker compose 命令，请先安装 Docker")

    # 校验 --tail
    if not MIN_TAIL <= args.tail <= MAX_TAIL:
        die(f"--tail 范围必须是 {MIN_TAIL}-{MAX_TAIL}")

    # 校验服务名
    invalid = [s for s in args.services if s not in ALLOWED_LOG_SERVICES]
    if invalid:
        die(
            f"不支持的日志服务名：{', '.join(invalid)}\n"
            f"允许的服务名：{', '.join(sorted(ALLOWED_LOG_SERVICES))}"
        )

    env_file = Path(args.env_file) if args.env_file else None
    cmd = build_base_cmd(compose, env_file) + [
        "logs",
        "--tail", str(args.tail),
    ]
    if args.follow:
        cmd.append("--follow")
    if args.timestamps:
        cmd.append("--timestamps")
    cmd.extend(args.services)
    return subprocess.call(cmd)


def cmd_stop(args: argparse.Namespace, project_dir: Path) -> int:
    compose = find_compose_file(project_dir)
    if not docker_available():
        die("未检测到 docker compose 命令，请先安装 Docker")
    env_file = Path(args.env_file) if args.env_file else None
    # down 默认不删除卷，与 --volumes 互斥
    cmd = build_base_cmd(compose, env_file) + [
        "down",
        "--remove-orphans",
    ]
    if args.volumes:
        cmd.append("--volumes")
    info("停止并移除容器与网络（不删除命名卷与镜像）")
    return subprocess.call(cmd)


def cmd_restart(args: argparse.Namespace, project_dir: Path) -> int:
    compose = find_compose_file(project_dir)
    if not docker_available():
        die("未检测到 docker compose 命令，请先安装 Docker")
    env_file = Path(args.env_file) if args.env_file else None
    cmd = build_base_cmd(compose, env_file) + ["restart"]
    if args.services:
        invalid = [s for s in args.services if s not in ALLOWED_LOG_SERVICES]
        if invalid:
            die(
                f"不支持的服务名：{', '.join(invalid)}\n"
                f"允许的服务名：{', '.join(sorted(ALLOWED_LOG_SERVICES))}"
            )
        cmd.extend(args.services)
    return subprocess.call(cmd)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="production_ops.py",
        description="闲鱼助手开源版生产运维包装器",
    )
    parser.add_argument(
        "--env-file",
        default=".env",
        help="环境变量文件路径（默认 .env）",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_status = sub.add_parser("status", help="查看所有服务状态（含已退出的一次性迁移服务）")
    p_status.set_defaults(func=cmd_status)

    p_logs = sub.add_parser("logs", help="查看服务日志")
    p_logs.add_argument("--tail", type=int, default=200, help=f"显示最后 N 行（{MIN_TAIL}-{MAX_TAIL}）")
    p_logs.add_argument("--follow", "-f", action="store_true", help="持续跟随日志输出")
    p_logs.add_argument("--timestamps", "-t", action="store_true", help="显示时间戳")
    p_logs.add_argument("services", nargs="*", help=f"服务名（允许：{', '.join(sorted(ALLOWED_LOG_SERVICES))}）")
    p_logs.set_defaults(func=cmd_logs)

    p_stop = sub.add_parser("stop", help="停止并移除容器与网络（不删除命名卷与镜像）")
    p_stop.add_argument(
        "--volumes", "-v",
        action="store_true",
        help="同时删除命名卷（MySQL/Redis 数据将永久丢失，慎用）",
    )
    p_stop.set_defaults(func=cmd_stop)

    p_restart = sub.add_parser("restart", help="重启服务")
    p_restart.add_argument("services", nargs="*", help="服务名（不指定则全部重启）")
    p_restart.set_defaults(func=cmd_restart)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    project_dir = Path(__file__).resolve().parent.parent
    return args.func(args, project_dir)


if __name__ == "__main__":
    sys.exit(main())
