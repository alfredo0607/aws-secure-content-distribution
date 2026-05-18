import { Router } from "express";
import cfg from "../config/app.js";

const { env, prefix } = cfg;

const router = Router();

// ── GET /health ───────────────────────────────────────────────────────────
/**
 * Health check endpoint.
 * Returns server status + DB connectivity.
 * Suitable for load-balancer / container orchestration probes.
 */
router.get("/health", async (_req, res) => {
  try {
    return res.status(200).json({
      message: "All systems operational",
      data: {
        status: "ok",
        env,
        db: "connected",
        uptime: `${Math.floor(process.uptime())}s`,
        memory: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)} MB`,
        time: new Date().toISOString(),
      },
    });
  } catch {
    return res.status(503).json({
      success: false,
      error: {
        code: "DB_UNAVAILABLE",
        message: "Database connection failed.",
      },
    });
  }
});

// ── GET / ─────────────────────────────────────────────────────────────────
router.get("/", (_req, res) => {
  return res.status(200).json({
    message: "Aws Secure Content Distribution API",
    data: {
      version: "1.0.0",
      prefix,
      docs: `${prefix}/docs`,
      health: "/health",
    },
  });
});

export default router;
