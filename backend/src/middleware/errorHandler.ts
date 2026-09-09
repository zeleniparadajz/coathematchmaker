import type { ErrorRequestHandler } from "express";
import { ZodError } from "zod";

export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string
  ) {
    super(message);
  }
}

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    return res.status(400).json({
      message: "Provjerite unesene podatke.",
      errors: err.flatten()
    });
  }

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ message: err.message });
  }

  if (err?.name === "CastError") {
    return res.status(400).json({ message: "Identifikator nije ispravan." });
  }

  if (err?.code === 11000) {
    return res.status(409).json({ message: "Zapis već postoji." });
  }

  console.error(err);
  return res.status(500).json({ message: "Greška na serveru. Pokušajte ponovo." });
};
