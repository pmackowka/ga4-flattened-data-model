from google import genai
from dotenv import load_dotenv
import os

# wczytanie zmiennych z pliku .env
load_dotenv()

# jawne pobranie klucza
api_key = os.getenv("GEMINI_API_KEY")

client = genai.Client(api_key=api_key)

try:
    response = client.models.generate_content(
        model="models/gemini-2.5-flash",
        contents="Explain how AI works in a few words"
    )
    print(response.text)

except Exception as e:
    print("ERROR:")
    print(e)