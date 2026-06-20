# Stage 1: Build React SPA
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package descriptors and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Copy codebase and compile TS/Vite assets
COPY src/ ./src/
COPY index.html tsconfig.json vite.config.ts ./
RUN npm run build

# Stage 2: Serve via Nginx
FROM nginx:alpine

# Copy custom reverse-proxy config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build assets
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
