import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import type { AuthTokenPayload, PublicUser } from "./types";

const BCRYPT_ROUNDS = 10;

export function jwtSecret(): string {
  return process.env.JWT_SECRET ?? "dev-only-change-me";
}

export function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

export function verifyPassword(password: string, passwordHash: string): Promise<boolean> {
  return bcrypt.compare(password, passwordHash);
}

export function signToken(user: PublicUser): string {
  const payload: AuthTokenPayload = { sub: user.id, email: user.email };
  return jwt.sign(payload, jwtSecret(), { expiresIn: "7d" });
}

export function verifyToken(token: string): AuthTokenPayload {
  const decoded = jwt.verify(token, jwtSecret());
  if (typeof decoded === "string" || typeof decoded.sub !== "string") {
    throw new Error("Invalid token");
  }
  const email = "email" in decoded ? decoded.email : undefined;
  if (typeof email !== "string") {
    throw new Error("Invalid token");
  }
  return { sub: decoded.sub, email };
}
