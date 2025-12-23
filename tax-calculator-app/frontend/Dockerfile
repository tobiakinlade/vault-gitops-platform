# Build stage
FROM node:18-alpine as builder

WORKDIR /app

COPY package*.json ./

# Change from npm ci to npm install
RUN npm install --production

COPY . .

RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=builder /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
