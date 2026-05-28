#!/bin/bash

# Test OpenAI API Key
# Usage: ./test-openai-key.sh sk-proj-your-key-here

if [ -z "$1" ]; then
  echo "Usage: ./test-openai-key.sh YOUR_OPENAI_KEY"
  exit 1
fi

API_KEY="$1"

echo "Testing OpenAI API key..."
echo ""

curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Say hi"}],
    "max_tokens": 10
  }'

echo ""
echo ""
echo "If you see a valid response above, your key works!"
echo "If you see an error, there's an issue with the key or your OpenAI account."

