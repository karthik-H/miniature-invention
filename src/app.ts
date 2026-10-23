import express, { type NextFunction, type Request, type Response } from "express";
import { signToken, verifyPassword, hashPassword, verifyToken } from "./auth";
import {
  createProduct,
  createUser,
  findProductById,
  findProductBySku,
  findUserByEmail,
  findUserById,
  listProducts,
  toPublicUser,
} from "./store";
import { normalizeEmail, readPassword, readProductInput } from "./validate";

export const app = express();

app.use(express.json({ limit: "100kb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/auth/register", async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const password = readPassword(req.body?.password);
  if (!email || !password) {
    res.status(400).json({
      error: "email must be valid and password must be 8-72 characters",
    });
    return;
  }
  if (findUserByEmail(email)) {
    res.status(409).json({ error: "An account with that email already exists" });
    return;
  }

  const user = createUser(email, await hashPassword(password));
  const publicUser = toPublicUser(user);
  res.status(201).json({ token: signToken(publicUser), user: publicUser });
});

app.post("/auth/login", async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const password = typeof req.body?.password === "string" ? req.body.password : "";
  const user = email ? findUserByEmail(email) : undefined;
  const matches = user ? await verifyPassword(password, user.passwordHash) : false;
  if (!user || !matches) {
    res.status(401).json({ error: "Invalid email or password" });
    return;
  }

  const publicUser = toPublicUser(user);
  res.json({ token: signToken(publicUser), user: publicUser });
});

function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.header("authorization") ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }
  try {
    const payload = verifyToken(match[1]);
    if (!findUserById(payload.sub)) {
      res.status(401).json({ error: "Invalid token" });
      return;
    }
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
}

app.post("/products", requireAuth, (req, res) => {
  const input = readProductInput(req.body);
  if ("error" in input) {
    res.status(400).json({ error: input.error });
    return;
  }
  if (findProductBySku(input.sku)) {
    res.status(409).json({ error: "A product with that sku already exists" });
    return;
  }
  res.status(201).json(createProduct(input));
});

app.get("/products", (_req, res) => {
  res.json({ products: listProducts() });
});

app.get("/products/:id", (req, res) => {
  const product = findProductById(req.params.id);
  if (!product) {
    res.status(404).json({ error: "Product not found" });
    return;
  }
  res.json(product);
});

app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof SyntaxError) {
    res.status(400).json({ error: "Invalid JSON" });
    return;
  }
  res.status(500).json({ error: "Internal server error" });
});
