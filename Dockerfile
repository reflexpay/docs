FROM node:20-alpine

WORKDIR /app

# Install Mintlify CLI used to serve docs.
RUN npm install -g mint

COPY . .

ENV NODE_ENV=production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000 >/dev/null || exit 1

CMD ["mint", "dev", "--host", "0.0.0.0", "--port", "3000"]

