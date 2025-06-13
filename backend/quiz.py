# user_type_quiz.py

def ask_user_questions():
    print("=== 性格診断 ===")

    q1 = input("Q1: 褒められるとやる気が出ますか？ (y/n): ").lower()
    q2 = input("Q2: キツめに言われた方が燃えますか？ (y/n): ").lower()
    q3 = input("Q3: 理屈で納得できないと動けませんか？ (y/n): ").lower()

    # Simple rules to determine type
    if q1 == "y" and q2 != "y":
        return "positive"
    elif q2 == "y":
        return "harsh"
    elif q3 == "y":
        return "logical"
    else:
        return "positive"  # default fallback

if __name__ == "__main__":
    from prompts import generate_message

    name = input("あなたの名前は？：")
    user_type = ask_user_questions()

    msg = generate_message(user_type, name)
    
    print("\n=== AIからのメッセージ ===")
    print(msg)
