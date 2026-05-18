import { Router } from "express";
import {
  deleteMe,
  forgotPassword,
  forgotPasswordSchema,
  login,
  loginSchema,
  me,
  register,
  registerSchema,
  resetPassword,
  resetPasswordPage,
  resetPasswordSchema,
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
authRoutes.post("/forgot-password", validate(forgotPasswordSchema), forgotPassword);
authRoutes.get("/reset-password", resetPasswordPage);
authRoutes.post("/reset-password", validate(resetPasswordSchema), resetPassword);
authRoutes.get("/me", authenticate, me);
authRoutes.delete("/me", authenticate, deleteMe);
