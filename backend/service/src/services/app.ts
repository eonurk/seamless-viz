import { existsSync, readFileSync } from "fs"
import { argv } from "process"
import express from 'express'
import cors from 'cors'
import morgan from 'morgan'

import { FirebaseModule } from "./firebase";
import { apiRoute } from "#root/routes/api";




export interface AppConfig {
  port?: number
  uploadsFolder?: string
  computeBackendUrl?: string
  corsOrigins?: string[]
  /**
   * Development escape hatch: accept every request as a fixed user instead of
   * verifying a Firebase ID token. Never honoured when NODE_ENV=production.
   */
  devAuth?: {
    enabled: boolean
    email: string
  }
  firebase: {
    serviceAccountFile: string
  }
}

const DEFAULT_CORS_ORIGINS = ["http://localhost:3000", "http://127.0.0.1:3000"]

function envFlag(name: string): boolean {
  const value = process.env[name]
  return value === "1" || value?.toLowerCase() === "true"
}

/**
 * Config comes from a JSON file (argv[2], historically debug.config.json) with
 * environment variables layered on top. Either source alone is sufficient, so
 * the container can run without a config file and a laptop can run without env.
 */
export function loadConfig(): AppConfig {
  const configPath = argv[2] || process.env.SEAMLESS_CONFIG_FILE || "config.json"

  let fileConfig: Partial<AppConfig> = {}
  if (existsSync(configPath)) {
    fileConfig = JSON.parse(readFileSync(configPath, { encoding: "utf-8" }))
  } else if (argv[2]) {
    // An explicitly named file that does not exist is a mistake worth surfacing.
    throw new Error(`config file not found: ${configPath}`)
  }

  const devAuthEnabled = envFlag("SEAMLESS_DEV_AUTH") || fileConfig.devAuth?.enabled === true

  const config: AppConfig = {
    ...fileConfig,
    port: Number(process.env.PORT) || fileConfig.port,
    uploadsFolder: process.env.SEAMLESS_UPLOADS_DIR || fileConfig.uploadsFolder,
    computeBackendUrl: process.env.SEAMLESS_COMPUTE_BACKEND_URL || fileConfig.computeBackendUrl,
    corsOrigins: process.env.SEAMLESS_CORS_ORIGINS
      ? process.env.SEAMLESS_CORS_ORIGINS.split(",").map((o) => o.trim()).filter(Boolean)
      : fileConfig.corsOrigins ?? DEFAULT_CORS_ORIGINS,
    devAuth: {
      enabled: devAuthEnabled,
      email: process.env.SEAMLESS_DEV_USER_EMAIL
        || fileConfig.devAuth?.email
        || "dev@localhost",
    },
    firebase: {
      serviceAccountFile: process.env.SEAMLESS_FIREBASE_CREDENTIALS
        || fileConfig.firebase?.serviceAccountFile
        || "",
    },
  }

  if (!config.devAuth!.enabled && !config.firebase.serviceAccountFile) {
    throw new Error(
      "No Firebase service account configured. Set SEAMLESS_FIREBASE_CREDENTIALS "
      + "(or firebase.serviceAccountFile in the config file), or enable the local "
      + "development bypass with SEAMLESS_DEV_AUTH=1.")
  }

  return config
}


function setupMiddlewares(app: express.Express, config: AppConfig) {
  app.use(morgan('combined'))
  app.use(cors({
    origin: config.corsOrigins ?? DEFAULT_CORS_ORIGINS
  }))

}


export function compose(config: AppConfig): express.Application {

  // With the dev bypass active no token is ever verified, so skip Firebase
  // initialisation entirely -- that is what lets the stack run with no
  // credentials on hand.
  const firebase = config.devAuth?.enabled
    ? null
    : new FirebaseModule(config.firebase.serviceAccountFile)

  const app = express()

  // common stuff
  setupMiddlewares(app, config)

  // bind business endpoints
  app.use("/v1", apiRoute({config, firebase}))

  // bind "ping" endpoint
  app.get('/', async (req, res) => {req.auth
    res.send('ok')
  })

  return app;
}
