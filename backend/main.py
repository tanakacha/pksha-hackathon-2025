# main.py
"""Bootstraps the google-calendar-mcp server *and* a LangChain agent in one
process.  Assumes you have already cloned
https://github.com/nspady/google-calendar-mcp and run `npm install`.

Environment Variables
---------------------
GCAL_MCP_REPO   Path to google-calendar-mcp repo (default "./google-calendar-mcp")
GOOGLE_OAUTH_CREDENTIALS  Path to OAuth creds (if required by the Node server)
MCP_PORT        Port to launch MCP on (default 3333)
OPENAI_API_KEY  Your OpenAI key (required by LangChain agent)

Run
---
$ python main.py "明日 14:00 から 45 分の設計レビューを作成してください"
"""
from __future__ import annotations

import os
import subprocess
import sys
import time
import platform
from pathlib import Path
from typing import Optional

import requests

# Import the agent helper from the companion module
from src.calendar_agent import run_query

# ----------------------------------------------------------------------------
# Configuration helpers
# ----------------------------------------------------------------------------
REPO_DIR = Path(os.getenv("GCAL_MCP_REPO", "./google-calendar-mcp")).expanduser().resolve()
MCP_PORT = int(os.getenv("MCP_PORT", "3333"))
MCP_BASE_URL = f"http://localhost:{MCP_PORT}"

# Expose to downstream libraries (langchain‑mcp‑adapters looks at this)
os.environ["MCP_BASE_URL"] = MCP_BASE_URL

# Windows対応のコマンド設定
if platform.system() == "Windows":
    NODE_CMD = [
        "npm.cmd",  # WindowsではNPMコマンドに.cmdが必要
        "start",
    ]
else:
NODE_CMD = [
    "npm",
        "start",
]

# ----------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------

def is_server_running(url: str) -> bool:
    """Check if MCP server is already running"""
    try:
        resp = requests.get(url, timeout=2)
        return resp.status_code == 200
    except requests.RequestException:
        return False

def start_mcp_server(repo: Path) -> subprocess.Popen:
    if not repo.exists():
        raise FileNotFoundError(f"MCP repo not found at {repo}")
    
    # 環境変数の設定
    env = os.environ.copy()
    env.setdefault("PORT", str(MCP_PORT))
    
    # Google OAuth認証情報のパスを設定
    oauth_path = repo / "gcp-oauth.keys.json"
    if oauth_path.exists():
        env["GOOGLE_OAUTH_CREDENTIALS"] = str(oauth_path)
    
    print(f"🚀 Launching MCP server at {MCP_BASE_URL} ...")
    print(f"📁 Working directory: {repo}")
    print(f"⚙️  Command: {' '.join(NODE_CMD)}")
    
    try:
    proc = subprocess.Popen(
        NODE_CMD,
        cwd=str(repo),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
            shell=True if platform.system() == "Windows" else False,  # Windowsではshell=Trueが必要な場合がある
    )
    return proc
    except FileNotFoundError as e:
        print(f"❌ Failed to start MCP server: {e}")
        print("💡 Make sure Node.js and npm are installed and available in PATH")
        raise


def wait_until_ready(url: str, timeout: int = 30):
    print("⏳ Waiting for MCP server to become ready ...")
    start = time.time()
    while time.time() - start < timeout:
        try:
            # The nspady MCP server exposes "/" which returns index HTML (200)
            resp = requests.get(url, timeout=1)
            if resp.status_code == 200:
                print("✅ MCP server is ready!")
                return True
        except requests.RequestException:
            pass
        time.sleep(1)
    return False


def main():
    print("🎯 Google Calendar MCP Agent Launcher")
    print(f"📂 Repository: {REPO_DIR}")
    print(f"🌐 Server URL: {MCP_BASE_URL}")
    
    # 1) Check if MCP server is already running
    if is_server_running(MCP_BASE_URL):
        print(f"✅ MCP server is already running at {MCP_BASE_URL}")
        proc = None
    else:
        # Launch MCP server
        try:
    proc = start_mcp_server(REPO_DIR)
        if not wait_until_ready(MCP_BASE_URL):
            print("❌ MCP server failed to start within timeout.")
                if proc:
            proc.terminate()
                sys.exit(1)
        except Exception as e:
            print(f"❌ Failed to start MCP server: {e}")
            print("🔧 You can manually start the server by running:")
            print(f"   cd {REPO_DIR}")
            print("   npm start")
            print("\nThen run the agent directly:")
            print("   python -c \"from src.calendar_agent import run_query; run_query('今日の予定を教えて')\"")
            sys.exit(1)

    try:
        # 2) Run the agent with the provided user query (or a default)
        user_query = " ".join(sys.argv[1:]).strip()
        if not user_query:
            user_query = "今日の予定を全て教えて"  # default
        run_query(user_query)

    finally:
        # 3) Clean‑up
        if proc:
        print("🛑 Shutting down MCP server ...")
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        else:
            print("🔄 MCP server was already running, left it as is")


if __name__ == "__main__":
    main()
