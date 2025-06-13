from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from backend.prompts import generate_message
from dotenv import load_dotenv
import os

# 環境変数を読み込み
load_dotenv()

app = FastAPI(title="Message Generator API", version="1.0.0")

def determine_user_type(positive: bool, harsh: bool, logical: bool) -> str:
    """
    True/Falseの組み合わせからユーザータイプを決定する
    quiz.pyのロジックに基づいて優先順位を設定
    """
    # quiz.pyのロジックを参考に優先順位を設定
    # q1=positive, q2=harsh, q3=logical として考える
    if positive and not harsh:
        return "positive"
    elif harsh:
        return "harsh"
    elif logical:
        return "logical"
    else:
        return "positive"  # デフォルトフォールバック

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
    positive: bool
    harsh: bool
    logical: bool
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
        request: 各ユーザータイプのTrue/False値とユーザー名を含むリクエスト
    
    Returns:
        生成されたメッセージとリクエスト情報
    
    Example:
        POST /generate-message
        {
            "positive": true,
            "harsh": false,
            "logical": false,
            "user_name": "たけし"
        }
    """
    try:
        # ユーザー名が空でないかチェック
        if not request.user_name.strip():
            raise HTTPException(
                status_code=400, 
                detail="user_name cannot be empty"
            )
        
        # True/Falseの組み合わせからユーザータイプを決定
        user_type = determine_user_type(request.positive, request.harsh, request.logical)
        
        if user_type is None:
            raise HTTPException(
                status_code=400,
                detail="Invalid user type combination. At least one type should be True, or use the priority logic."
            )
        
        # prompts.pyのgenerate_message関数を使ってメッセージを生成
        message = generate_message(user_type, request.user_name.strip())
        
        return MessageResponse(
            message=message,
            user_type=user_type,
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
                "description": "褒められた方がやる気が出るか？冷静に分析してほしいか？"
            },
            {
                "type": "harsh", 
                "description": "キツめに言われた方が燃えるか？優しく言われたいか？"
            },
            {
                "type": "logical",
                "description": "理屈で納得できないと動けませんか？感情的に説得してほしいか？"
            }
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 