# INFRAESTRUTURA COMPLETA - Crypto Monitor 🚀

## Como usar esses arquivos:

1. Copie cada arquivo para o seu repositório no caminho correto
2. Execute: `docker-compose up -d`
3. Acesse: http://localhost:3000

---

## ARQUIVO 1: .env.example
```env
ENVIRONMENT=development
NODE_ENV=development

DB_HOST=postgres
DB_PORT=5432
DB_USER=crypto_user
DB_PASSWORD=crypto_password
DB_NAME=crypto_db

REDIS_URL=redis://redis:6379/0
REDIS_HOST=redis
REDIS_PORT=6379

API_PORT=8000
API_URL=http://localhost:8000
FRONTEND_URL=http://localhost:3000

SECRET_KEY=your-super-secret-key-change-in-production
JWT_SECRET=your-jwt-secret-key-change-in-production
JWT_EXPIRES_IN=7d

BINANCE_API_KEY=your_binance_api_key
BINANCE_API_SECRET=your_binance_api_secret
GITHUB_API_TOKEN=your_github_token

LOG_LEVEL=info
LOG_FORMAT=json

CORS_ORIGIN=http://localhost:3000

RATE_LIMIT_WINDOW=15m
RATE_LIMIT_MAX_REQUESTS=100
```

---

## ARQUIVO 2: .gitignore
```gitignore
node_modules/
*.lock
yarn.lock

.env
.env.local
.env.*.local

logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

pids/
*.pid
*.seed
*.pid.lock

coverage/
.nyc_output/

.DS_Store
.vscode/
.idea/
*.swp
*.swo

data/
*.json
!package.json
!package-lock.json

build/
dist/
.cache/

.dockerignore
```

---

## ARQUIVO 3: docker-compose.yml
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: crypto-monitor-db
    environment:
      POSTGRES_USER: ${DB_USER:-crypto_user}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-crypto_password}
      POSTGRES_DB: ${DB_NAME:-crypto_db}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "${DB_PORT:-5432}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-crypto_user}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: crypto-monitor-cache
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: crypto-monitor-api
    environment:
      ENVIRONMENT: ${ENVIRONMENT:-development}
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: ${DB_USER:-crypto_user}
      DB_PASSWORD: ${DB_PASSWORD:-crypto_password}
      DB_NAME: ${DB_NAME:-crypto_db}
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY:-your-secret-key-change-in-production}
      BINANCE_API_KEY: ${BINANCE_API_KEY}
      GITHUB_API_TOKEN: ${GITHUB_API_TOKEN}
      LOG_LEVEL: ${LOG_LEVEL:-INFO}
    ports:
      - "${API_PORT:-8000}:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./backend:/app
      - /app/__pycache__
    command: npm start

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: crypto-monitor-web
    environment:
      API_URL: ${API_URL:-http://localhost:8000}
    ports:
      - "${FRONTEND_PORT:-3000}:3000"
    depends_on:
      - backend

volumes:
  postgres_data:
  redis_data:
```

---

## Próximos Passos:

1. **Clone o repositório**
   ```bash
   git clone https://github.com/Molingsaibam/crypto-monitor.git
   cd crypto-monitor
   ```

2. **Crie a estrutura de pastas**
   ```bash
   mkdir -p backend/src/{routes,middleware,config}
   mkdir -p frontend/{js,styles}
   mkdir -p scripts
   mkdir -p .github/workflows
   ```

3. **Copie os arquivos** que mostrei para seus respectivos locais

4. **Inicie os containers**
   ```bash
   cp .env.example .env
   docker-compose up -d
   ```

5. **Verifique a saúde**
   ```bash
   curl http://localhost:8000/health
   ```

---

**Quer que eu mostre os arquivos completos de um por um? Ou prefere que crie um script que gera tudo de uma vez?**
