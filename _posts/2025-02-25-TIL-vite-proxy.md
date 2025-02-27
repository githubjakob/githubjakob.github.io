---
title: "Vite Proxy Server"
date: 2025-02-25
category: til
---

Today I learned that [Vite has a proxy server config](https://vite.dev/config/server-options#server-proxy) so that in local development API requests can go to `http://localhost:3000/api` while the server can run on `http://localhost:5000`. This saves you from having to configure CORS in the backend for local dev purposes only.