import { randomUUID } from "node:crypto";
import type { Product, PublicUser, User } from "./types";

const usersById = new Map<string, User>();
const usersByEmail = new Map<string, User>();
const productsById = new Map<string, Product>();
const productIdBySku = new Map<string, string>();

export function toPublicUser(user: User): PublicUser {
  return { id: user.id, email: user.email, createdAt: user.createdAt };
}

export function findUserByEmail(email: string): User | undefined {
  return usersByEmail.get(email);
}

export function findUserById(id: string): User | undefined {
  return usersById.get(id);
}

export function createUser(email: string, passwordHash: string): User {
  const user: User = {
    id: randomUUID(),
    email,
    passwordHash,
    createdAt: new Date().toISOString(),
  };
  usersById.set(user.id, user);
  usersByEmail.set(user.email, user);
  return user;
}

export function listProducts(): Product[] {
  return [...productsById.values()];
}

export function findProductById(id: string): Product | undefined {
  return productsById.get(id);
}

export function findProductBySku(sku: string): Product | undefined {
  const id = productIdBySku.get(sku);
  return id ? productsById.get(id) : undefined;
}

export function createProduct(input: {
  name: string;
  description: string;
  priceCents: number;
  sku: string;
}): Product {
  const product: Product = {
    id: randomUUID(),
    name: input.name,
    description: input.description,
    priceCents: input.priceCents,
    sku: input.sku,
    createdAt: new Date().toISOString(),
  };
  productsById.set(product.id, product);
  productIdBySku.set(product.sku, product.id);
  return product;
}
