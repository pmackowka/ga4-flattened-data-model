from google import genai
import os
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

try:
    response = client.models.generate_content(
        model="models/gemini-2.0-flash",
        contents="Check my quota and explain GA4 session attribution briefly"
    )
    print(response.text)

except Exception as e:
    print("ERROR:")
    print(e)