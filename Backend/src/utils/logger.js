/**
 * Serveo Production Structured Logger
 *
 * Implements structured JSON logging with correlation IDs, automatic redaction
 * of credentials and sensitive payment data, and distinct logging categories.
 */

const SENSITIVE_KEYS = new Set([
  "password",
  "token",
  "authorization",
  "private_key",
  "privatekey",
  "secret",
  "apikey",
  "api_key",
  "cookie",
  "creditcard",
  "cardnumber",
  "cvv",
]);

/**
 * Deep redaction of sensitive objects prior to logging.
 */
export function sanitizeLogData(data, depth = 0) {
  if (depth > 5) return "[Max Depth Reached]";
  if (!data || typeof data !== "object") return data;

  if (Array.isArray(data)) {
    return data.map((item) => sanitizeLogData(item, depth + 1));
  }

  const sanitized = {};
  for (const [key, val] of Object.entries(data)) {
    const lowerKey = key.toLowerCase();
    if (SENSITIVE_KEYS.has(lowerKey)) {
      sanitized[key] = "[REDACTED]";
    } else if (typeof val === "string" && (val.startsWith("Bearer ") || val.includes("BEGIN PRIVATE KEY"))) {
      sanitized[key] = "[REDACTED_CREDENTIAL]";
    } else if (typeof val === "object" && val !== null) {
      sanitized[key] = sanitizeLogData(val, depth + 1);
    } else {
      sanitized[key] = val;
    }
  }
  return sanitized;
}

export const logger = {
  info(category, message, meta = {}) {
    const logEntry = {
      level: "INFO",
      timestamp: new Date().toISOString(),
      category,
      message,
      ...sanitizeLogData(meta),
    };
    console.log(JSON.stringify(logEntry));
    return logEntry;
  },

  warn(category, message, meta = {}) {
    const logEntry = {
      level: "WARN",
      timestamp: new Date().toISOString(),
      category,
      message,
      ...sanitizeLogData(meta),
    };
    console.warn(JSON.stringify(logEntry));
    return logEntry;
  },

  error(category, message, error = null, meta = {}) {
    const errorDetails = error
      ? {
          errorMessage: error.message || String(error),
          errorCode: error.code,
          status: error.status || error.statusCode || 500,
        }
      : {};

    const logEntry = {
      level: "ERROR",
      timestamp: new Date().toISOString(),
      category,
      message,
      ...errorDetails,
      ...sanitizeLogData(meta),
    };
    console.error(JSON.stringify(logEntry));
    return logEntry;
  },

  audit(restaurantId, actor, action, target, details = {}) {
    const logEntry = {
      level: "AUDIT",
      timestamp: new Date().toISOString(),
      category: "admin_audit",
      restaurantId: restaurantId ? restaurantId.toString() : null,
      actor: sanitizeLogData(actor),
      action,
      target,
      details: sanitizeLogData(details),
    };
    console.log(JSON.stringify(logEntry));
    return logEntry;
  },
};

