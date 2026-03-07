import * as functions from "firebase-functions/v1";

export const appleSignInCallback = functions.https.onRequest((req, res) => {
  try {
    const androidPackage = process.env.ANDROID_APP_PACKAGE;

    if (!androidPackage) {
      res.status(500).send("Missing ANDROID_APP_PACKAGE in functions/.env");
      return;
    }

    const source =
      req.method === "POST" && req.body && Object.keys(req.body).length > 0 ?
        req.body :
        req.query;

    const params = new URLSearchParams();

    const appendIfExists = (key: string) => {
      const raw = source[key];
      if (raw == null) return;

      if (Array.isArray(raw)) {
        if (raw.length > 0) params.set(key, String(raw[0]));
        return;
      }

      if (typeof raw === "object") {
        params.set(key, JSON.stringify(raw));
        return;
      }

      params.set(key, String(raw));
    };

    appendIfExists("code");
    appendIfExists("id_token");
    appendIfExists("state");
    appendIfExists("user");
    appendIfExists("error");
    appendIfExists("error_description");

    const redirectUrl =
      `intent://callback?${params.toString()}` +
      `#Intent;package=${androidPackage};scheme=signinwithapple;end`;

    functions.logger.info("appleSignInCallback redirect", {redirectUrl});

    res.redirect(302, redirectUrl);
  } catch (e) {
    functions.logger.error("appleSignInCallback error", e);
    res.status(500).send("Apple callback failed");
  }
});
