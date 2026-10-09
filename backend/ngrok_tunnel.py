"""
ngrok_tunnel.py — Run this SEPARATELY to expose app.py over the internet.
Start app.py first, then run this.
"""

import os, sys
from dotenv import load_dotenv

try:
    from pyngrok import ngrok
except ImportError:
    print("\n❌ 'pyngrok' is not installed.")
    print("👉 Please install it by running: pip install pyngrok\n")
    sys.exit(1)

load_dotenv()

NGROK_TOKEN = os.getenv("NGROK_TOKEN")
if NGROK_TOKEN:
    ngrok.set_auth_token(NGROK_TOKEN)

# Connect to the port your app.py is already running on
tunnel = ngrok.connect(8000)
print("\n" + "="*50)
print(f"  Public URL: {tunnel.public_url}")
print("  Use this URL as BASE_URL for remote testing.")
print("="*50 + "\n")

print("Tunnel is live. Press Ctrl+C to close it.")
try:
    input()
except KeyboardInterrupt:
    ngrok.disconnect(tunnel.public_url)
    ngrok.kill()
    print("Tunnel closed.")
