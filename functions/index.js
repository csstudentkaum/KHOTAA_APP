const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { RtcTokenBuilder, RtcRole } = require("agora-token");
const admin = require("firebase-admin");

admin.initializeApp();

// Store the App Certificate as a Firebase secret (never in source code)
// Set it once via: firebase functions:secrets:set AGORA_APP_CERTIFICATE
const agoraAppCertificate = defineSecret("AGORA_APP_CERTIFICATE");

const AGORA_APP_ID = "33c11816e2984bc9963980c3018720dd";

/**
 * HTTP function: GET /getAgoraToken?channelName=xxx&uid=0
 * Requires: Authorization: Bearer <Firebase ID token>
 *
 * Returns: { "token": "..." }
 *
 * Token is valid for 1 hour. The app should call this before every call
 * and handle renewal via onTokenPrivilegeWillExpire.
 */
exports.getAgoraToken = onRequest(
  { secrets: [agoraAppCertificate], cors: true },
  async (req, res) => {
    // Verify Firebase Auth token
    const authHeader = req.headers.authorization ?? "";
    const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!idToken) {
      res.status(401).json({ error: "Unauthorized: missing token" });
      return;
    }
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      res.status(401).json({ error: "Unauthorized: invalid token" });
      return;
    }

    const channelName = req.query.channelName;
    const uid = parseInt(req.query.uid ?? "0", 10);

    if (!channelName) {
      res.status(400).json({ error: "channelName is required" });
      return;
    }

    const certificate = agoraAppCertificate.value();
    if (!certificate) {
      res.status(500).json({ error: "App Certificate not configured" });
      return;
    }

    const expirationSeconds = 3600; // 1 hour
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      certificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
      privilegeExpiredTs
    );

    res.json({ token });
  }
);
