# calendar_langchain_agent.py
"""LangChain agent that controls the nspady/google-calendar-mcp server.

Prerequisites
=============
1. **Run the MCP server** (Node.js)

   ```bash
   git clone https://github.com/nspady/google-calendar-mcp.git
   cd google-calendar-mcp
   # install deps + build
   npm install
   # authenticate once (opens browser)
   GOOGLE_OAUTH_CREDENTIALS="/abs/path/to/gcp-oauth.keys.json" npm run auth
   # start the server (defaults to http://localhost:3333)
   npm start  # internally calls node build/index.js
   ```

   After launch you should see a line such as:

   ```text
   🟢 MCP Server listening on http://localhost:3333
   ```

   Use that URL as `MCP_BASE_URL` below.

2. **Python environment**

   ```bash
   pip install langchain==0.2.2 langchain-mcp-adapters==0.1.8 openai python-dotenv
   export OPENAI_API_KEY="sk-..."  # or set in .env
   ```

Usage Example
=============
```bash
python calendar_langchain_agent.py "明日 10:00 に 30 分のランチミーティングを作成して"
```

The agent will automatically pick the correct MCP tool (e.g. `create_event`) and
return a confirmation message.
"""
from __future__ import annotations

import sys
import os
import asyncio
from datetime import datetime, time
from typing import List, Optional
from pathlib import Path
from pydantic import BaseModel, Field

# python-dotenvを使って環境変数を読み込み
from dotenv import load_dotenv

# .envファイルのパスを指定（存在しない場合はスキップ）
env_path = Path(__file__).parent.parent / "config" / ".env"
if env_path.exists():
    load_dotenv(env_path)
    print(f"📁 Loaded environment variables from {env_path}")
else:
    print(f"⚠️  No .env file found at {env_path}")
    print("🔧 Please ensure OPENAI_API_KEY is set in your environment or create the .env file")

from langchain_openai.chat_models import ChatOpenAI
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent


# -------------------- Pydantic Models --------------------
class WorkoutTimeSlot(BaseModel):
    """筋トレ時間の提案"""
    time: str = Field(..., description="最適な筋トレの開始時間（HH:MM形式）", pattern=r"^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")
    reason: str = Field(..., description="この時間を選んだ理由")
    duration_minutes: int = Field(default=60, description="推奨筋トレ時間（分）")

# class WorkoutScheduleResponse(BaseModel):
#     """筋トレスケジュールの回答"""
#     date: str = Field(..., description="対象日（YYYY-MM-DD形式）")
#     recommended_times: List[WorkoutTimeSlot] = Field(..., description="推奨筋トレ時間のリスト")
#     message: str = Field(..., description="ユーザーへのメッセージ")

# -------------------- Settings --------------------
REPO_DIR = Path(os.getenv("GCAL_MCP_REPO", "./google-calendar-mcp")).expanduser().resolve()
REASONING_MODEL_NAME = os.environ.get("REASONING_MODEL_NAME", "o3-mini")
MODEL_NAME = os.environ.get("OPENAI_MODEL", "gpt-4o")

# -------------------- Init MCP + Tools --------------------
print(f"🔗 Connecting to MCP via stdio transport ...")

# 複数のMCPサーバーを設定
client = MultiServerMCPClient({
    "calendar": {
        "command": "node",
        "args": [str(REPO_DIR / "build" / "index.js")],
        "transport": "stdio",
        "env": {
            "GOOGLE_OAUTH_CREDENTIALS": str(REPO_DIR / "gcp-oauth.keys.json"),
            "TZ": "Asia/Tokyo",
            "TIMEZONE": "Asia/Tokyo"
        }
    },
    "datetime": {
        "command": sys.executable,
        "args": ["-m", "mcp_datetime"],
        "transport": "stdio",
        "env": {
            "PYTHONPATH": str(Path(__file__).parent.parent / "mcp-datetime" / "src"),
            "TZ": "Asia/Tokyo"
        }
    }
})

async def init_tools():
    """非同期でツールを初期化"""
    print("📥 Loading tools from MCP server ...")
    all_tools = await client.get_tools()  # これでasyncになった
    
    # OpenAIのFunction Callingで問題が発生するツールを除外
    excluded_tools = ["update-event", "get-current-time", "get-current-timezone"]  # スキーマに問題があるツール
    
    filtered_tools = [tool for tool in all_tools if tool.name not in excluded_tools]
    
    print(f"   {len(all_tools)} tools loaded, {len(filtered_tools)} tools after filtering:")
    for t in filtered_tools:
        print(f"   • {t.name}")
    
    if len(all_tools) != len(filtered_tools):
        print(f"   ⚠️  Excluded {len(all_tools) - len(filtered_tools)} problematic tools: {excluded_tools}")
    
    return filtered_tools

# -------------------- Build LangChain Agent --------------------
REASONING_SYSTEM_PROMPT = """
# 役割
- あなたは筋トレのスケジュールを考えるアシスタントです。

# 目的
- 予定の無い時間を有効活用して、筋トレを行うためのスケジュールを考えてください。
- 予定の無い時間の中で、最も適した時間に筋トレを行いたいです。

# 規則
- 健康を損なうことは避けてください。
    - 睡眠は7時間以上取るようにしてください。
    - 食事は3食を摂るようにしてください。
- 予定がある場合はそれを優先してください。
- 筋トレは自宅で行う事とします。
    - 自宅までの移動の時間も考慮してください。
"""

SYSTEM_PROMPT = """
# 役割
- あなたはカレンダーの予定を管理するアシスタントです。

# 目的
- ユーザーの予定を管理して、予定の埋まっている時間とその内容を把握して下さい。

# 規則
- Googleカレンダーの操作を行う事ができます。
- Datetimeツールを使用して、日時を取得することができます。
- 日時は日本標準時（JST, UTC+9）で処理してください。
- カレンダーAPIを呼び出す際は、`timeZone='Asia/Tokyo'`パラメータを指定してください。
- 時刻表記は24時間形式（HH:MM）を使用してください。
- 日付は'YYYY-MM-DD'形式で指定してください。
- 相対的な日時表現（今日、明日、来週など）が出てきたら、まずDatetimeツールで具体的な日時に変換し、その後Calendarツールで予定を確認してください。
"""

time_choice_llm = ChatOpenAI(model=REASONING_MODEL_NAME)
structured_llm = time_choice_llm.with_structured_output(WorkoutTimeSlot)
# structured_llm = llm.with_structured_output(WorkoutScheduleResponse)

tool_use_llm = ChatOpenAI(model=MODEL_NAME)
tool_use_llm = tool_use_llm.bind(system=SYSTEM_PROMPT)

# -------------------- CLI interface --------------------

async def run_query_async(query: str):
    """非同期クエリ実行"""
    tools = await init_tools()
    
    agent = create_react_agent(model=tool_use_llm, tools=tools)
    
    print("📝 User:", query)
    
    # エージェントの実行結果を収集
    final_response = None
    async for event in agent.astream({"messages": [{"role": "user", "content": query}]}):
        # 手動でイベントストリームを処理
        if "messages" in event:
            for message in event["messages"]:
                if hasattr(message, 'content'):
                    print(f"🤖 {message.content}")
                    if hasattr(message, 'type') and message.type == 'ai':
                        final_response = message.content
        elif "agent" in event:
            if "messages" in event["agent"]:
                for message in event["agent"]["messages"]:
                    if hasattr(message, 'content'):
                        print(f"🤖 {message.content}")
                        if hasattr(message, 'type') and message.type == 'ai':
                            final_response = message.content
        elif "tools" in event:
            if "messages" in event["tools"]:
                for message in event["tools"]["messages"]:
                    if hasattr(message, 'content'):
                        print(f"🔧 Tool: {message.content}")
    
    # 最終回答を構造化された形式で再処理
    if final_response:
        try:
            print("\n" + "="*50)
            print("📋 構造化された筋トレスケジュール:")
            print("="*50)
            
            # 構造化されたLLMで最終回答を処理
            structured_response = await structured_llm.ainvoke(
                f"""
                スケジュールの情報を元に、筋トレを開始する時間を考えてください。
                
                ### スケジュールの情報
                {final_response}
                """
            )
            
            # print(f"📅 対象日: {structured_response.date}")
            # print(f"💬 メッセージ: {structured_response.message}")
            # print("\n⏰ 推奨筋トレ時間:")
            # for i, slot in enumerate(structured_response.recommended_times, 1):
            #     print(f"  {i}. {slot.time} ({slot.duration_minutes}分)")
            #     print(f"     理由: {slot.reason}")
            
            print(structured_response.time)
            print(structured_response.reason)
            print(structured_response.duration_minutes)

        except Exception as e:
            print(f"\n⚠️ 構造化処理でエラーが発生しました: {e}")
            print("通常の回答を表示しています。")

def run_query(query: str):
    """同期ラッパー"""
    asyncio.run(run_query_async(query))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python calendar_langchain_agent.py \"<自然言語の指示>\"")
        sys.exit(1)
    run_query(sys.argv[1])

""" Add datetime server config"""
