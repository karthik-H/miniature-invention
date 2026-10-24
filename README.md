# miniature-invention

TypeScript ecommerce API. Accounts register and log in with a bearer token. Authenticated callers add products to the catalog; anyone can read them.

Data lives in memory and resets when the process stops.

## Run

```bash
npm install
npm run dev
```

`npm run build` then `npm start` serves the compiled output. Set `PORT` (default `3000`) and `JWT_SECRET` (default is a local-only value).

## Endpoints

| Method | Path | Auth | Body |
| --- | --- | --- | --- |
| POST | `/auth/register` | no | `{ "email", "password" }` |
| POST | `/auth/login` | no | `{ "email", "password" }` |
| POST | `/products` | bearer token | `{ "name", "description", "priceCents", "sku" }` |
| GET | `/products` | no | |
| GET | `/products/:id` | no | |
| GET | `/health` | no | |

Passwords must be 8–72 characters. `priceCents` is a non-negative integer. `sku` is unique and uses letters, numbers, `_`, or `-`.

```bash
curl -s -X POST localhost:3000/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"ada@example.com","password":"correct-horse"}'

curl -s -X POST localhost:3000/products \
  -H 'content-type: application/json' \
  -H 'authorization: Bearer TOKEN' \
  -d '{"name":"Notebook","description":"Ruled, 80 pages","priceCents":1299,"sku":"NB-80"}'

curl -s localhost:3000/products
```
