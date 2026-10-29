const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;
const geminiApiKey = process.env.GEMINI_API_KEY;
const geminiModel = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';
const proxySecret = process.env.PROXY_SECRET;

app.use(cors());
app.use(express.json({ limit: '10kb' })); // Minimal payload size restriction

// Rate Limiter: max 60 requests per 15 minutes per IP
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many advisor requests. Please try again later.'
  }
});
app.use('/api/', apiLimiter);

// Privacy & Schema Validation Middleware
function validatePrivacyPayload(req, res, next) {
  const body = req.body;
  if (!body || typeof body !== 'object') {
    return res.status(400).json({ error: 'Invalid request body' });
  }

  // Strict check: forbidden privacy-sensitive keys
  const forbiddenKeys = ['image', 'bytes', 'rawText', 'text', 'maskedPreview', 'file', 'path', 'uri', 'secret', 'document'];
  for (const key of Object.keys(body)) {
    if (forbiddenKeys.includes(key.toLowerCase())) {
      return res.status(400).json({
        error: `Privacy Violation: Payload must never contain '${key}'. Send only abstract categories and confidence.`
      });
    }
  }

  const { purpose, audience, findings } = body;
  if (!purpose || typeof purpose !== 'string') {
    return res.status(400).json({ error: "Missing or invalid 'purpose' string" });
  }
  if (!audience || typeof audience !== 'string') {
    return res.status(400).json({ error: "Missing or invalid 'audience' string" });
  }
  if (!Array.isArray(findings)) {
    return res.status(400).json({ error: "Missing or invalid 'findings' array" });
  }

  // Verify each finding only contains type and confidence
  for (let i = 0; i < findings.length; i++) {
    const f = findings[i];
    if (!f || typeof f !== 'object') {
      return res.status(400).json({ error: `Finding at index ${i} is invalid` });
    }
    if (!f.type || typeof f.type !== 'string') {
      return res.status(400).json({ error: `Finding at index ${i} is missing 'type'` });
    }
    for (const key of Object.keys(f)) {
      if (key !== 'type' && key !== 'confidence') {
        return res.status(400).json({
          error: `Privacy Violation: Finding at index ${i} contains forbidden field '${key}'`
        });
      }
    }
  }

  next();
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'overshare-advisor-proxy',
    model: geminiModel,
    hasApiKey: Boolean(geminiApiKey && geminiApiKey !== 'your_gemini_api_key_here')
  });
});

// Advisory endpoint
app.post('/api/advise', validatePrivacyPayload, async (req, res) => {
  // Optional Proxy Secret verification
  if (proxySecret && req.headers['x-proxy-secret'] !== proxySecret) {
    return res.status(401).json({ error: 'Unauthorized proxy secret' });
  }

  const { purpose, audience, findings } = req.body;

  // If no findings, return empty advice immediately
  if (findings.length === 0) {
    return res.json({
      model: geminiModel,
      advice: [],
      generalContext: 'No sensitive findings were identified for this context.'
    });
  }

  // If no live API key is configured, return deterministic advisory mock
  if (!geminiApiKey || geminiApiKey === 'your_gemini_api_key_here') {
    return res.json(generateLocalMockAdvice(purpose, audience, findings));
  }

  try {
    const prompt = buildGeminiPrompt(purpose, audience, findings);
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiApiKey}`;

    const requestPayload = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: 'OBJECT',
          properties: {
            advice: {
              type: 'ARRAY',
              items: {
                type: 'OBJECT',
                properties: {
                  type: { type: 'STRING' },
                  explanation: { type: 'STRING' },
                  clarifyingQuestion: { type: 'STRING' }
                },
                required: ['type', 'explanation']
              }
            },
            generalContext: { type: 'STRING' }
          },
          required: ['advice']
        }
      }
    };

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestPayload)
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('Gemini API Error:', response.status, errText);
      return res.status(502).json({ error: 'Upstream AI model returned an error' });
    }

    const data = await response.json();
    const candidate = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!candidate) {
      return res.status(502).json({ error: 'Empty response from AI model' });
    }

    const parsed = JSON.parse(candidate);
    return res.json({
      model: geminiModel,
      advice: parsed.advice || [],
      generalContext: parsed.generalContext || null
    });
  } catch (error) {
    console.error('Advisor Proxy Failure:', error);
    return res.status(500).json({ error: 'Internal advisor proxy error' });
  }
});

function buildGeminiPrompt(purpose, audience, findings) {
  const findingsSummary = findings.map(f => `- Category: ${f.type} (confidence: ${(f.confidence * 100).toFixed(0)}%)`).join('\n');
  return `You are an expert, privacy-first cybersecurity advisor assisting a user before they share a screenshot.
Context:
- Sharing Purpose: ${purpose}
- Intended Audience: ${audience}

Detected Data Categories:
${findingsSummary}

CRITICAL RULES:
1. You are ADVISORY ONLY. Do NOT create new findings, do NOT override decisions, and do NOT prescribe actions.
2. For each detected category, explain in 1 concise sentence why exposing it could matter in this specific (purpose x audience) context.
3. Formulate 1 helpful clarifying question that helps the user decide whether the recipient truly needs this information.
4. Return strictly JSON matching the required schema.`;
}

function generateLocalMockAdvice(purpose, audience, findings) {
  const isPublic = audience.toLowerCase().includes('public');
  const advice = findings.map(f => {
    let explanation = `Exposing ${f.type} can lead to unintended identity correlation or privacy exposure.`;
    let question = `Does the recipient strictly require your ${f.type} to fulfill this request?`;

    if (f.type.toLowerCase().includes('card')) {
      explanation = `Card numbers allow unauthorized billing attempts and financial fraud.`;
      question = `Can you redact the 16-digit card number and leave only the last 4 digits visible?`;
    } else if (f.type.toLowerCase().includes('aadhaar') || f.type.toLowerCase().includes('pan')) {
      explanation = `National identity numbers can be exploited for identity theft or unauthorized SIM swapping.`;
      question = `Does the counterparty have legal verification authorization to view your national ID?`;
    } else if (f.type.toLowerCase().includes('phone') || f.type.toLowerCase().includes('email')) {
      explanation = isPublic
        ? `Sharing contact details publicly frequently results in automated spam and targeted phishing.`
        : `Direct contact details may be recorded into third-party ticketing systems.`;
      question = `Is sharing your personal direct contact information necessary for this interaction?`;
    } else if (f.type.toLowerCase().includes('transaction') || f.type.toLowerCase().includes('amount')) {
      explanation = `Transaction references confirm payment settlement without revealing underlying banking credentials.`;
      question = `Will the recipient accept the reference number without your phone or account number?`;
    }

    return {
      type: f.type,
      explanation,
      clarifyingQuestion: question
    };
  });

  return {
    model: 'overshare-local-advisory-engine',
    advice,
    generalContext: `Reviewing ${findings.length} item(s) for ${purpose} shared with ${audience}.`
  };
}

// Start server if executed directly
if (require.main === module) {
  app.listen(port, () => {
    console.log(`[Overshare Advisor Proxy] Running on http://localhost:${port}`);
    console.log(`[Overshare Advisor Proxy] Model configured: ${geminiModel}`);
    console.log(`[Overshare Advisor Proxy] API Key present: ${Boolean(geminiApiKey && geminiApiKey !== 'your_gemini_api_key_here')}`);
  });
}

module.exports = app;
