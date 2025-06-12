"""
FastAPI application for Google Calendar Agent

This FastAPI app provides a REST API interface for the Google Calendar Agent,
allowing users to interact with Google Calendar through natural language queries.

Features:
- POST /query: Send natural language queries to the calendar agent
- GET /health: Health check endpoint
- WebSocket support for real-time responses
- CORS enabled for browser access
"""

import asyncio
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
import subprocess
import sys
from pathlib import Path

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
import uvicorn

from src.calendar_agent import init_tools, tool_use_llm, structured_llm, WorkoutTimeSlot
from langgraph.prebuilt import create_react_agent

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Pydantic models for request/response
class QueryRequest(BaseModel):
    query: str = Field(..., description="自然言語でのカレンダーへの質問", example="今日の予定を教えて")
    stream: bool = Field(False, description="ストリーミングレスポンスを使用するかどうか")

class CalendarResponse(BaseModel):
    success: bool = Field(..., description="処理が成功したかどうか")
    response: str = Field(..., description="エージェントからの回答")
    timestamp: datetime = Field(default_factory=datetime.now, description="レスポンス時刻")
    query: str = Field(..., description="元のクエリ")
    structured_result: Optional[WorkoutTimeSlot] = Field(None, description="構造化された筋トレスケジュール結果")

class HealthResponse(BaseModel):
    status: str = Field(..., description="サービスの状態")
    timestamp: datetime = Field(default_factory=datetime.now, description="ヘルスチェック時刻")
    mcp_status: str = Field(..., description="MCPサーバーの状態")

class ErrorResponse(BaseModel):
    error: str = Field(..., description="エラーメッセージ")
    detail: Optional[str] = Field(None, description="詳細なエラー情報")
    timestamp: datetime = Field(default_factory=datetime.now, description="エラー発生時刻")

# グローバル変数でツールとエージェントを管理
_tools_cache: Optional[List] = None
_agent_cache: Optional[Any] = None

async def get_tools():
    """ツールをキャッシュから取得、または初期化"""
    global _tools_cache
    if _tools_cache is None:
        logger.info("Initializing MCP tools...")
        try:
            _tools_cache = await init_tools()
            logger.info(f"Initialized {len(_tools_cache)} tools")
        except Exception as e:
            import traceback
            logger.error(f"Failed to initialize MCP tools: {e}")
            logger.error(f"MCP tools traceback: {traceback.format_exc()}")
            raise
    return _tools_cache

async def get_agent():
    """エージェントをキャッシュから取得、または初期化"""
    global _agent_cache
    if _agent_cache is None:
        logger.info("Initializing Calendar Agent...")
        tools = await get_tools()
        _agent_cache = create_react_agent(model=tool_use_llm, tools=tools)
        logger.info("Calendar Agent initialized")
    return _agent_cache

async def execute_calendar_query(query: str) -> tuple[str, Optional[WorkoutTimeSlot]]:
    """カレンダークエリを実行して結果を返す"""
    agent = await get_agent()
    
    # エージェントの実行結果を収集
    final_response = ""
    tool_outputs = []
    
    async for event in agent.astream({"messages": [{"role": "user", "content": query}]}):
        # エージェントからのメッセージを処理
        if "messages" in event:
            for message in event["messages"]:
                if hasattr(message, 'content') and message.content:
                    if hasattr(message, 'type') and message.type == 'ai':
                        final_response = message.content
        elif "agent" in event:
            if "messages" in event["agent"]:
                for message in event["agent"]["messages"]:
                    if hasattr(message, 'content') and message.content:
                        if hasattr(message, 'type') and message.type == 'ai':
                            final_response = message.content
        elif "tools" in event:
            if "messages" in event["tools"]:
                for message in event["tools"]["messages"]:
                    if hasattr(message, 'content') and message.content:
                        tool_outputs.append(message.content)
    
    # 構造化された結果を生成（筋トレスケジュール関連の場合）
    structured_result = None
    if any(keyword in query.lower() for keyword in ["筋トレ", "ワークアウト", "運動", "トレーニング", "空き時間"]):
        try:
            structured_result = await structured_llm.ainvoke(
                f"""
                スケジュールの情報を元に、筋トレを開始する時間を考えてください。
                
                ### スケジュールの情報
                {final_response}
                """
            )
        except Exception as e:
            logger.warning(f"Failed to generate structured result: {e}")
    
    return final_response, structured_result

def run_calendar_agent_sync(query: str) -> tuple[str, Optional[Dict]]:
    """同期的にcalendar_agentを実行"""
    try:
        # calendar_agent.pyを別プロセスで実行
        script_path = Path(__file__).parent / "src" / "calendar_agent.py"
        
        result = subprocess.run(
            [sys.executable, str(script_path), query],
            capture_output=True,
            text=True,
            encoding='utf-8',
            cwd=Path(__file__).parent
        )
        
        if result.returncode == 0:
            # 出力から構造化された結果を抽出
            output_lines = result.stdout.strip().split('\n')
            
            # 最後の3行が構造化された結果（time, reason, duration）
            if len(output_lines) >= 3:
                time_line = output_lines[-3].strip()
                reason_line = output_lines[-2].strip()
                duration_line = output_lines[-1].strip()
                
                # 時間形式をチェック（HH:MM）
                if ':' in time_line and len(time_line.split(':')) == 2:
                    try:
                        duration = int(duration_line)
                        structured_result = {
                            "time": time_line,
                            "reason": reason_line,
                            "duration_minutes": duration
                        }
                    except ValueError:
                        structured_result = None
                else:
                    structured_result = None
            else:
                structured_result = None
            
            # 全体の出力をレスポンスとして返す
            response_text = result.stdout.strip()
            
            return response_text, structured_result
        else:
            logger.error(f"Calendar agent failed: {result.stderr}")
            return f"エラーが発生しました: {result.stderr}", None
            
    except Exception as e:
        logger.error(f"Failed to run calendar agent: {e}")
        return f"システムエラー: {str(e)}", None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションの起動・終了時の処理"""
    # 起動時: 基本的な初期化のみ
    logger.info("🚀 Starting Google Calendar Agent API...")
    logger.info("✅ API server initialized (MCP will be initialized on first request)")
    
    yield
    
    # 終了時の処理
    logger.info("🛑 Shutting down Google Calendar Agent API...")

# FastAPIアプリケーション初期化
app = FastAPI(
    title="Google Calendar Agent API",
    description="自然言語でGoogleカレンダーを操作するAIエージェントのAPI",
    version="1.0.0",
    lifespan=lifespan
)

# CORS設定（ブラウザからのアクセスを許可）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切なドメインを指定
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", response_model=Dict[str, str])
async def root():
    """ルートエンドポイント"""
    return {
        "message": "Google Calendar Agent API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """ヘルスチェックエンドポイント"""
    try:
        # 簡単なテストクエリでMCPの動作確認
        test_response, _ = run_calendar_agent_sync("今日の日付を教えて")
        
        if "エラー" in test_response or "システムエラー" in test_response:
            return HealthResponse(
                status="degraded",
                mcp_status="MCP connection failed"
            )
        else:
            return HealthResponse(
                status="healthy",
                mcp_status="MCP connection successful"
            )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(
            status_code=503,
            detail=ErrorResponse(
                error="Service unavailable",
                detail=str(e)
            ).dict()
        )

@app.post("/query", response_model=CalendarResponse)
async def query_calendar(request: QueryRequest):
    """
    自然言語でカレンダーに質問する
    
    例:
    - "今日の予定を教えて"
    - "明日の午後に会議を追加して"
    - "来週の空いている時間は？"
    - "今日筋トレする時間を教えて"
    """
    try:
        logger.info(f"Received query: {request.query}")
        
        # calendar_agentを実行
        response_text, structured_result = run_calendar_agent_sync(request.query)
        
        # 空の場合のフォールバック
        if not response_text.strip():
            response_text = "カレンダーの操作が完了しました。"
        
        logger.info(f"Query completed successfully")
        
        return CalendarResponse(
            success=True,
            response=response_text.strip(),
            query=request.query,
            structured_result=structured_result
        )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in query_calendar: {e}")
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error="Internal server error",
                detail=str(e)
            ).dict()
        )

@app.post("/query/stream")
async def query_calendar_stream(request: QueryRequest):
    """
    ストリーミングレスポンスでカレンダーに質問する
    
    リアルタイムでエージェントの思考過程と結果が返されます。
    """
    try:
        logger.info(f"Received streaming query: {request.query}")
        
        tools = await get_tools()
        if not tools:
            raise HTTPException(status_code=503, detail="MCP tools are not available")
        
        async def generate_response():
            try:
                agent = await get_agent()
                
                async for event in agent.astream({"messages": [{"role": "user", "content": request.query}]}):
                    # イベントの種類に応じて適切な形式で出力
                    if "messages" in event:
                        for message in event["messages"]:
                            if hasattr(message, 'content') and message.content:
                                if hasattr(message, 'type'):
                                    if message.type == 'ai':
                                        yield f"data: 🤖 {message.content}\n\n"
                                    elif message.type == 'tool':
                                        yield f"data: 🔧 Tool: {message.content}\n\n"
                                    else:
                                        yield f"data: {message.content}\n\n"
                    elif "agent" in event:
                        if "messages" in event["agent"]:
                            for message in event["agent"]["messages"]:
                                if hasattr(message, 'content') and message.content:
                                    yield f"data: 🤖 {message.content}\n\n"
                    elif "tools" in event:
                        if "messages" in event["tools"]:
                            for message in event["tools"]["messages"]:
                                if hasattr(message, 'content') and message.content:
                                    yield f"data: 🔧 Tool: {message.content}\n\n"
                
                yield f"data: [DONE]\n\n"
                
            except Exception as e:
                yield f"data: ❌ Error: {str(e)}\n\n"
                logger.error(f"Error in streaming response: {e}")
        
        return StreamingResponse(
            generate_response(),
            media_type="text/plain",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "Content-Type": "text/plain; charset=utf-8"
            }
        )
        
    except Exception as e:
        logger.error(f"Error in query_calendar_stream: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# 筋トレスケジュール専用エンドポイント
@app.post("/workout-schedule", response_model=WorkoutTimeSlot)
async def get_workout_schedule(request: QueryRequest):
    """
    筋トレスケジュールに特化したエンドポイント
    
    例:
    - "今日筋トレする時間を教えて"
    - "明日の空き時間で筋トレしたい"
    """
    try:
        logger.info(f"Received workout schedule query: {request.query}")
        
        # 筋トレ関連のクエリに変換
        workout_query = f"筋トレをする時間を見つけて: {request.query}"
        
        response_text, structured_result = await execute_calendar_query(workout_query)
        
        if structured_result is None:
            # 構造化結果が生成されなかった場合、再試行
            try:
                structured_result = await structured_llm.ainvoke(
                    f"""
                    以下の情報から筋トレに最適な時間を選んでください：
                    {response_text}
                    
                    ユーザーの質問: {request.query}
                    """
                )
            except Exception as e:
                logger.error(f"Failed to generate structured workout schedule: {e}")
                raise HTTPException(
                    status_code=500,
                    detail="筋トレスケジュールの生成に失敗しました"
                )
        
        return structured_result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_workout_schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Flutterアプリ向けシンプルエンドポイント
class WorkoutTimeResponse(BaseModel):
    """Flutterアプリ向けシンプルな筋トレ時間レスポンス"""
    time: str = Field(..., description="筋トレ開始時間（HH:MM形式）", example="14:00")
    success: bool = Field(True, description="取得成功フラグ")
    timestamp: datetime = Field(default_factory=datetime.now, description="取得時刻")

@app.get("/workout-time", response_model=WorkoutTimeResponse)
async def get_workout_time():
    """
    Flutterアプリ向け：今日の最適な筋トレ時間を取得
    
    固定クエリで今日の筋トレ時間を取得し、時間のみを返す
    定期的な問い合わせに最適化されたシンプルなエンドポイント
    """
    try:
        logger.info("Flutter app requested workout time")
        
        # 固定クエリで今日の筋トレ時間を取得
        fixed_query = "今日筋トレをするのに最適な時間を教えて"
        
        response_text, structured_result = run_calendar_agent_sync(fixed_query)
        
        if structured_result and "time" in structured_result:
            workout_time = structured_result["time"]
            success = True
        else:
            # フォールバック時間
            workout_time = "18:00"
            success = False
            logger.warning("Failed to extract structured workout time, using fallback")
        
        logger.info(f"Generated workout time: {workout_time}")
        
        return WorkoutTimeResponse(
            time=workout_time,
            success=success,
            timestamp=datetime.now()
        )
        
    except Exception as e:
        logger.error(f"Error in get_workout_time: {e}")
        # エラー時はフォールバック時間を返す
        return WorkoutTimeResponse(
            time="18:00",
            success=False,
            timestamp=datetime.now()
        )

@app.get("/workout-time/tomorrow", response_model=WorkoutTimeResponse)
async def get_tomorrow_workout_time():
    """
    Flutterアプリ向け：明日の最適な筋トレ時間を取得
    """
    try:
        logger.info("Flutter app requested tomorrow's workout time")
        
        # 明日の筋トレ時間を取得
        fixed_query = "明日筋トレをするのに最適な時間を教えて"
        
        response_text, structured_result = run_calendar_agent_sync(fixed_query)
        
        if structured_result and "time" in structured_result:
            workout_time = structured_result["time"]
            success = True
        else:
            workout_time = "18:00"
            success = False
            logger.warning("Failed to extract structured workout time for tomorrow, using fallback")
        
        logger.info(f"Generated tomorrow's workout time: {workout_time}")
        
        return WorkoutTimeResponse(
            time=workout_time,
            success=success,
            timestamp=datetime.now()
        )
        
    except Exception as e:
        logger.error(f"Error in get_tomorrow_workout_time: {e}")
        return WorkoutTimeResponse(
            time="18:00",
            success=False,
            timestamp=datetime.now()
        )

if __name__ == "__main__":
    # 開発用サーバー起動
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    ) 