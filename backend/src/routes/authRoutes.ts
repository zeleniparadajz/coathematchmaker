import { Router } from "express";
import {
  login,
  loginSchema,
  me,
  register,
  registerSchema,
  resendVerification,
  resendVerificationSchema,
  verifyEmail
} from "../controllers/authController";
import { authenticate } from "../middleware/auth";
import { validate } from "../middleware/validate";

export const authRoutes = Router();

authRoutes.post("/register", validate(registerSchema), register);
authRoutes.post("/login", validate(loginSchema), login);
authRoutes.get("/verify-email", verifyEmail);
authRoutes.post("/resend-verification", validate(resendVerificationSchema), resendVerification);
authRoutes.get("/me", authenticate, me);
