import dotenv from "dotenv";

dotenv.config();

const required = (name: string, fallback?: string): string => {
  const value = process.env[name] ?? fallback;

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

const numberFromEnv = (name: string, fallback: number): number => {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;

  const parsed = Number(raw);
  if (!Number.isSafeInteger(parsed) || parsed < 1) {
    throw new Error(`${name} must be a positive integer build number`);
  }
  return parsed;
};

const defaultMinSupportedBuild = numberFromEnv("APP_MIN_SUPPORTED_BUILD", 1);
const defaultLatestBuild = numberFromEnv("APP_LATEST_BUILD", defaultMinSupportedBuild);

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 4000),
  mongoUri: required("MONGO_URI", "mongodb://localhost:27017/coathematchmaker"),
  jwtSecret: required("JWT_SECRET"),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? "7d",
  corsOrigin: process.env.CORS_ORIGIN ?? "*",
  adminRegistrationCode: process.env.ADMIN_REGISTRATION_CODE,
  appUrl: process.env.APP_URL ?? "http://localhost:4000",
  minSupportedBuild: defaultMinSupportedBuild,
  latestBuild: defaultLatestBuild,
  iosMinSupportedBuild: numberFromEnv("APP_IOS_MIN_SUPPORTED_BUILD", defaultMinSupportedBuild),
  iosLatestBuild: numberFromEnv("APP_IOS_LATEST_BUILD", defaultLatestBuild),
  androidMinSupportedBuild: numberFromEnv("APP_ANDROID_MIN_SUPPORTED_BUILD", defaultMinSupportedBuild),
  androidLatestBuild: numberFromEnv("APP_ANDROID_LATEST_BUILD", defaultLatestBuild),
  playStoreUrl: process.env.PLAY_STORE_URL ?? "",
  appStoreUrl: process.env.APP_STORE_URL ?? "",
  appUpdateMessage:
    process.env.APP_UPDATE_MESSAGE ??
    "Nova verzija aplikacije je obavezna. Ažuriraj COA The Matchmaker.",
  requireEmailVerification: process.env.REQUIRE_EMAIL_VERIFICATION !== "false",
  resendApiKey: process.env.RESEND_API_KEY,
  googlePlacesApiKey: process.env.GOOGLE_PLACES_API_KEY ?? "",
  emailFrom: process.env.EMAIL_FROM ?? "Coa The Matchmaker <onboarding@resend.dev>"
};
