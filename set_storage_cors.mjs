// Run: node set_storage_cors.mjs
// Configures Firebase Storage CORS to allow web app access.

import { GoogleAuth } from 'google-auth-library';

const BUCKET = 'khotaa-app.firebasestorage.app';
const CORS_CONFIG = [
  {
    origin: ['*'],
    method: ['GET', 'HEAD', 'OPTIONS'],
    responseHeader: ['Content-Type', 'Authorization', 'x-goog-resumable'],
    maxAgeSeconds: 3600,
  },
];

async function setCors() {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/devstorage.full_control'],
  });

  const client = await auth.getClient();
  const token = await client.getAccessToken();

  const response = await fetch(
    `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(BUCKET)}?fields=cors`,
    {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ cors: CORS_CONFIG }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to set CORS: ${response.status} ${text}`);
  }

  console.log('✅ Firebase Storage CORS configured successfully!');
  const result = await response.json();
  console.log(JSON.stringify(result, null, 2));
}

setCors().catch(console.error);
