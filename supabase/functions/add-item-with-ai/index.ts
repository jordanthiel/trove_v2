import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = req.headers.get('Authorization')
    const authResponse = authorization ? await fetch(`${Deno.env.get('SUPABASE_URL')}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: Deno.env.get('SUPABASE_ANON_KEY')! },
    }) : null
    if (!authResponse?.ok) {
      return new Response(JSON.stringify({ error: 'Authentication required' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const { link, message, conversationHistory = [] } = await req.json()
    
    const openAIApiKey = Deno.env.get('OPENAI_API_KEY') ?? Deno.env.get('OPEN_AI_API_KEY')
    if (!openAIApiKey) {
      return new Response(
        JSON.stringify({ error: 'OpenAI API key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // If link is provided, parse it to extract product info
    if (link && !message) {
      // First, fetch the page content
      let pageContent = ''
      try {
        const pageResponse = await fetch(link, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
          },
        })
        
        if (pageResponse.ok) {
          const html = await pageResponse.text()
          
          // Extract relevant text content from HTML
          // Remove scripts, styles, and other non-content elements
          const textContent = html
            .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
            .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
            .replace(/<[^>]+>/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .substring(0, 10000) // Limit to first 10k chars to avoid token limits
          
          pageContent = textContent
        }
      } catch (fetchError) {
        console.error('Error fetching page:', fetchError)
        // Continue anyway - OpenAI might still be able to help with just the URL
      }

      const messages = [
        {
          role: 'system',
          content: `You are a product information extractor. Given product page content or a URL, extract the following information:
- Product name/title
- Price (if available, in USD)
- A brief description

Respond with ONLY a JSON object in this exact format (no markdown, no backticks):
{
  "ready": true,
  "item": {
    "name": "Product Name",
    "description": "Brief description of the product",
    "price": 29.99,
    "link": "original_url"
  }
}

If you cannot extract the information or the link seems invalid, respond with:
{
  "ready": false,
  "message": "Could not extract product information from this link. Please add details manually."
}`,
        },
        {
          role: 'user',
          content: pageContent 
            ? `Extract product information from this Amazon product page content:\n\n${pageContent}\n\nOriginal URL: ${link}`
            : `Extract product information from this Amazon product URL: ${link}\n\nNote: I couldn't fetch the page content, but try to extract what you can from the URL structure.`,
        },
      ]

      const openAIResponse = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openAIApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages,
          temperature: 0.3,
          max_tokens: 500,
        }),
      })
      console.log('openAIResponse', openAIResponse);

      if (!openAIResponse.ok) {
        const error = await openAIResponse.text()
        console.error('OpenAI API error:', error)
        return new Response(
          JSON.stringify({ error: 'Failed to parse product link' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const openAIData = await openAIResponse.json()
      const aiMessage = openAIData.choices[0].message.content

      try {
        // Remove markdown code blocks if present
        const cleanedMessage = aiMessage.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
        const parsed = JSON.parse(cleanedMessage)
        
        return new Response(
          JSON.stringify({
            success: true,
            response: parsed,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      } catch (parseError) {
        return new Response(
          JSON.stringify({
            success: true,
            response: {
              ready: false,
              message: "I couldn't extract product information from that link. Please try adding the details manually.",
            },
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Regular conversation flow (no link)
    if (!message) {
      return new Response(
        JSON.stringify({ error: 'Message or link is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const messages = [
      {
        role: 'system',
        content: `You are a helpful gift registry assistant. Your job is to help users add items to their wish lists.

When a user describes what they want, you should:
1. Ask clarifying questions if needed (color, size, brand preferences, etc.)
2. Once you have enough information, provide a structured gift item suggestion

When you're ready to suggest an item, respond with a JSON object in this exact format (no markdown, no backticks):
{
  "ready": true,
  "item": {
    "name": "Product Name",
    "description": "Detailed description including any specifications mentioned",
    "price": 29.99,
    "link": "https://www.google.com/search?q=product+name+keywords"
  }
}

The link should be a Google search URL that will help someone find the product.
The price should be an estimated price in USD (use null if you're not sure).

If you need more information, respond with:
{
  "ready": false,
  "message": "Your question or clarification request"
}

Be friendly, conversational, and helpful. Remember you're helping someone create their wish list!`,
      },
      ...conversationHistory,
      {
        role: 'user',
        content: message,
      },
    ]

    const openAIResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages,
        temperature: 0.7,
        max_tokens: 500,
      }),
    })

    if (!openAIResponse.ok) {
      const error = await openAIResponse.text()
      console.error('OpenAI API error:', error)
      return new Response(
        JSON.stringify({ error: 'Failed to get AI response' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const openAIData = await openAIResponse.json()
    const aiMessage = openAIData.choices[0].message.content

    try {
      // Remove markdown code blocks if present
      const cleanedMessage = aiMessage.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
      const parsed = JSON.parse(cleanedMessage)
      
      return new Response(
        JSON.stringify({
          success: true,
          response: parsed,
          conversationHistory: [
            ...conversationHistory,
            { role: 'user', content: message },
            { role: 'assistant', content: aiMessage },
          ],
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } catch (parseError) {
      // If not valid JSON, treat as a regular message
      return new Response(
        JSON.stringify({
          success: true,
          response: {
            ready: false,
            message: aiMessage,
          },
          conversationHistory: [
            ...conversationHistory,
            { role: 'user', content: message },
            { role: 'assistant', content: aiMessage },
          ],
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
