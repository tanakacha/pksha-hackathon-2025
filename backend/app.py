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

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
import uvicorn

from src.calendar_agent import run_query_async, init_tools
from src.calendar_agent import client as mcp_client

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Pydantic models for request/response
class QueryRequest(BaseModel):
    query: str = Field(..., description="自然言語でのカレンダーへの質問", example="今日の予定を教えて")
    stream: bool = Field(False, description="ストリーミングレスポンスを使用するかどうか")

class QueryResponse(BaseModel):
    success: bool = Field(..., description="処理が成功したかどうか")
    response: str = Field(..., description="エージェントからの回答")
    timestamp: datetime = Field(default_factory=datetime.now, description="レスポンス時刻")
    query: str = Field(..., description="元のクエリ")

class HealthResponse(BaseModel):
    status: str = Field(..., description="サービスの状態")
    timestamp: datetime = Field(default_factory=datetime.now, description="ヘルスチェック時刻")
    mcp_tools_count: int = Field(..., description="利用可能なMCPツール数")

class ErrorResponse(BaseModel):
    error: str = Field(..., description="エラーメッセージ")
    detail: Optional[str] = Field(None, description="詳細なエラー情報")
    timestamp: datetime = Field(default_factory=datetime.now, description="エラー発生時刻")

# グローバル変数でツールを管理
_tools_cache: Optional[List] = None

async def get_tools():
    """ツールをキャッシュから取得、または初期化"""
    global _tools_cache
    if _tools_cache is None:
        logger.info("Initializing MCP tools...")
        _tools_cache = await init_tools()
        logger.info(f"Initialized {len(_tools_cache)} tools")
    return _tools_cache

@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションの起動・終了時の処理"""
    # 起動時: ツールを事前初期化
    logger.info("🚀 Starting Google Calendar Agent API...")
    try:
        tools = await get_tools()
        logger.info(f"✅ Successfully initialized {len(tools)} MCP tools")
    except Exception as e:
        logger.error(f"❌ Failed to initialize MCP tools: {e}")
        logger.warning("⚠️  API will start but calendar functionality may not work")
    
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
        tools = await get_tools()
        return HealthResponse(
            status="healthy",
            mcp_tools_count=len(tools)
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

@app.post("/query", response_model=QueryResponse)
async def query_calendar(request: QueryRequest):
    """
    自然言語でカレンダーに質問する
    
    例:
    - "今日の予定を教えて"
    - "明日の午後に会議を追加して"
    - "来週の空いている時間は？"
    """
    try:
        logger.info(f"Received query: {request.query}")
        
        # ツールが利用可能か確認
        tools = await get_tools()
        if not tools:
            raise HTTPException(
                status_code=503,
                detail="MCP tools are not available"
            )
        
        # クエリを実行（結果をキャプチャ）
        response_parts = []
        
        # run_query_asyncを呼び出して結果をキャプチャ
        # 注意: run_query_asyncは現在printで出力しているので、
        # レスポンスをキャプチャできるようにする必要があります
        
        # 一時的な解決策として、元のrun_queryを使用
        import io
        import sys
        from contextlib import redirect_stdout
        
        # 標準出力をキャプチャ
        output_buffer = io.StringIO()
        
        try:
            # エージェントを直接実行してレスポンスをキャプチャ
            from src.calendar_agent import llm, SYSTEM_PROMPT
            from langgraph.prebuilt import create_react_agent
            
            # システムプロンプトをLLMに組み込む
            llm_with_system = llm.bind(
                system="You are an AI assistant that manages Google Calendar via provided tools. "
                       "You have access to both calendar tools and datetime tools. "
                       "All times should be handled in Japan Standard Time (JST, UTC+9). "
                       "When users mention relative dates like '今日' (today), '明日' (tomorrow), '来週' (next week), etc., "
                       "FIRST use the datetime tools to convert these to specific dates and times in JST, "
                       "THEN use the calendar tools with the converted dates. "
                       "Think step-by-step, decide which tool is needed, then call the tool with "
                       "JSON arguments. Use RFC3339 + timezone (JST) in all date/time arguments."
            )
            
            agent = create_react_agent(model=llm_with_system, tools=tools)
            
            response_text = ""
            async for event in agent.astream({"messages": [{"role": "user", "content": request.query}]}):
                # イベントから応答を抽出
                if "messages" in event:
                    for message in event["messages"]:
                        if hasattr(message, 'content') and message.content:
                            if hasattr(message, 'type') and message.type == 'ai':
                                response_text += message.content + "\n"
                elif "agent" in event:
                    if "messages" in event["agent"]:
                        for message in event["agent"]["messages"]:
                            if hasattr(message, 'content') and message.content:
                                if hasattr(message, 'type') and message.type == 'ai':
                                    response_text += message.content + "\n"
            
            # 空の場合のフォールバック
            if not response_text.strip():
                response_text = "カレンダーの操作が完了しました。"
            
            logger.info(f"Query completed successfully")
            
            return QueryResponse(
                success=True,
                response=response_text.strip(),
                query=request.query
            )
            
        except Exception as e:
            logger.error(f"Error executing agent: {e}")
            raise
            
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
                from src.calendar_agent import llm
                from langgraph.prebuilt import create_react_agent
                
                # システムプロンプトをLLMに組み込む
                llm_with_system = llm.bind(
                    system="You are an AI assistant that manages Google Calendar via provided tools. "
                           "You have access to both calendar tools and datetime tools. "
                           "All times should be handled in Japan Standard Time (JST, UTC+9). "
                           "When users mention relative dates like '今日' (today), '明日' (tomorrow), '来週' (next week), etc., "
                           "FIRST use the datetime tools to convert these to specific dates and times in JST, "
                           "THEN use the calendar tools with the converted dates. "
                           "Think step-by-step, decide which tool is needed, then call the tool with "
                           "JSON arguments. Use RFC3339 + timezone (JST) in all date/time arguments."
                )
                
                agent = create_react_agent(model=llm_with_system, tools=tools)
                
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

if __name__ == "__main__":
    # 開発用サーバー起動
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    ) 