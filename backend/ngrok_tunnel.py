"""
ngrok_tunnel.py — Run this SEPARATELY to expose app.py over the internet.
Start app.py first, then run this.
"""

from pyngrok import ngrok
import os
from dotenv import load_dotenv

load_dotenv()

NGROK_TOKEN = os.getenv("NGROK_TOKEN")
ngrok.set_auth_token(NGROK_TOKEN)

# Connect to the port your app.py is already running on
tunnel = ngrok.connect(8000)
print("\n" + "="*50)
print(f"  Public URL: {tunnel.public_url}")
print(f"  Share this with your friend!")
print("="*50 + "\n")

print("Tunnel is live. Press Ctrl+C to close it.")
try:
    input()
except KeyboardInterrupt:
    ngrok.disconnect(tunnel.public_url)
    ngrok.kill()
    print("Tunnel closed.")