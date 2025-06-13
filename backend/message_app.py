from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from backend.prompts import generate_message
from dotenv import load_dotenv
import os

# 環境変数を読み込み
load_dotenv()

app = FastAPI(title="Message Generator API", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切なオリジンを指定
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# リクエストモデル
class MessageRequest(BaseModel):
    user_type: str  # "positive", "harsh", "logical"
    user_name: str

# レスポンスモデル
class MessageResponse(BaseModel):
    message: str
    user_type: str
    user_name: str

@app.get("/")
async def root():
    """ルートエンドポイント"""
    return {"message": "Message Generator API is running", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """ヘルスチェック用エンドポイント"""
    return {"status": "healthy", "service": "message-generator"}

@app.post("/generate-message", response_model=MessageResponse)
async def generate_user_message(request: MessageRequest):
    """
    ユーザータイプと名前を受け取り、パーソナライズされたメッセージを生成する
    
    Args:
        request: ユーザータイプ（positive/harsh/logical）とユーザー名を含むリクエスト
    
    Returns:
        生成されたメッセージとリクエスト情報
    
    Example:
        POST /generate-message
        {
            "user_type": "positive",
            "user_name": "たけし"
        }
    """
    try:
        # 有効なユーザータイプをチェック（quiz.pyで定義されている値）
        valid_types = ["positive", "harsh", "logical"]
        if request.user_type not in valid_types:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid user_type. Must be one of: {', '.join(valid_types)}"
            )
        
        # ユーザー名が空でないかチェック
        if not request.user_name.strip():
            raise HTTPException(
                status_code=400, 
                detail="user_name cannot be empty"
            )
        
        # prompts.pyのgenerate_message関数を使ってメッセージを生成
        message = generate_message(request.user_type, request.user_name.strip())
        
        return MessageResponse(
            message=message,
            user_type=request.user_type,
            user_name=request.user_name.strip()
        )
        
    except HTTPException:
        # HTTPExceptionはそのまま再発生
        raise
    except Exception as e:
        # OpenAI APIエラーやその他のエラーをハンドリング
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to generate message: {str(e)}"
        )

@app.get("/user-types")
async def get_user_types():
    """利用可能なユーザータイプの一覧を返す"""
    return {
        "user_types": [
            {
                "type": "positive",
                "description": "明るく元気でポジティブなパーソナルトレーナー"
            },
            {
                "type": "harsh", 
                "description": "熱血すぎて温度がおかしいパーソナルトレーナー"
            },
            {
                "type": "logical",
                "description": "理性的だが冷めている年上の女性トレーナー"
            }
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 