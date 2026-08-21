# Production/SSR Frontend Dockerfile
FROM node:22-alpine

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm install --legacy-peer-deps

# Copy frontend source
COPY . .

EXPOSE 8080

# Start frontend application on 0.0.0.0:8080
CMD ["npx", "vite", "dev", "--host", "0.0.0.0", "--port", "8080"]

