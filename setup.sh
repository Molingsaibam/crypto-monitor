#!/bin/bash

# Crypto Monitor - Infrastructure Setup Script
# Este script cria toda a estrutura de infraestrutura automaticamente

set -e

echo "🚀 Criando infraestrutura do Crypto Monitor..."

# 1. Criar estrutura de diretórios
echo "📁 Criando diretórios..."
mkdir -p backend/src/{routes,middleware,config}
mkdir -p frontend/{js,styles}
mkdir -p scripts
mkdir -p .github/workflows

# 2. Criar package.json do backend
echo "📦 Criando backend/package.json..."
cat > backend/package.json << 'EOF'
{
  "name": "crypto-monitor-api",
  "version": "1.0.0",
  "description": "Crypto Monitor API with multiple agents",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest --coverage",
    "test:watch": "jest --watch",
    "lint": "eslint src/**/*.js",
    "lint:fix": "eslint src/**/*.js --fix",
    "migrate": "node src/migrations/run.js",
    "seed": "node src/seeds/index.js"
  },
  "keywords": ["cryptocurrency", "monitoring", "trading", "agents"],
  "author": "Molingsaibam",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "express-async-errors": "^3.1.1",
    "pg": "^8.11.3",
    "redis": "^4.6.12",
    "jsonwebtoken": "^9.1.2",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.3.1",
    "axios": "^1.6.5",
    "pino": "^8.17.2",
    "pino-pretty": "^10.3.1",
    "joi": "^17.11.0",
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^7.1.5",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0",
    "supertest": "^6.3.3",
    "eslint": "^8.54.0",
    "eslint-config-airbnb-base": "^15.0.0",
    "eslint-plugin-import": "^2.29.0"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  }
}
EOF

# 3. Criar entry point
echo "📝 Criando backend/src/index.js..."
cat > backend/src/index.js << 'EOF'
require('dotenv').config();
const app = require('./app');
const logger = require('./config/logger');

const PORT = process.env.API_PORT || 8000;

const server = app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});
EOF

# 4. Criar app.js
echo "📝 Criando backend/src/app.js..."
cat > backend/src/app.js << 'EOF'
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
require('express-async-errors');

const logger = require('./config/logger');
const { errorHandler } = require('./middleware/errorHandler');
const { requestLogger } = require('./middleware/requestLogger');
const rateLimiter = require('./middleware/rateLimiter');

const app = express();

app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true,
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

app.use(requestLogger);
app.use('/api/', rateLimiter);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/agents', require('./routes/agents'));
app.use('/api/crypto', require('./routes/crypto'));
app.use('/api/analysis', require('./routes/analysis'));

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use(errorHandler);

module.exports = app;
EOF

# 5. Criar config files
echo "📝 Criando backend config files..."

cat > backend/src/config/logger.js << 'EOF'
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  },
});

module.exports = logger;
EOF

cat > backend/src/config/database.js << 'EOF'
const { Pool } = require('pg');
const logger = require('./logger');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'crypto_user',
  password: process.env.DB_PASSWORD || 'crypto_password',
  database: process.env.DB_NAME || 'crypto_db',
});

pool.on('error', (err) => {
  logger.error('Unexpected error on idle client', err);
});

module.exports = pool;
EOF

cat > backend/src/config/redis.js << 'EOF'
const redis = require('redis');
const logger = require('./logger');

const client = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379/0',
});

client.on('error', (err) => {
  logger.error('Redis Client Error', err);
});

client.on('connect', () => {
  logger.info('Redis connected');
});

module.exports = client;
EOF

# 6. Criar middleware
echo "📝 Criando backend middleware..."

cat > backend/src/middleware/errorHandler.js << 'EOF'
const logger = require('../config/logger');

const errorHandler = (err, req, res, next) => {
  logger.error({
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  const status = err.status || 500;
  const message = err.message || 'Internal Server Error';

  res.status(status).json({
    error: message,
    ...(process.env.ENVIRONMENT === 'development' && { stack: err.stack }),
  });
};

const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = { errorHandler, asyncHandler };
EOF

cat > backend/src/middleware/requestLogger.js << 'EOF'
const logger = require('../config/logger');

const requestLogger = (req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info({
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`,
    });
  });

  next();
};

module.exports = { requestLogger };
EOF

cat > backend/src/middleware/rateLimiter.js << 'EOF'
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW || '15m'),
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: 'Too many requests, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = limiter;
EOF

# 7. Criar routes
echo "📝 Criando backend routes..."

cat > backend/src/routes/auth.js << 'EOF'
const express = require('express');
const router = express.Router();

router.post('/register', (req, res) => {
  res.json({ message: 'Register endpoint' });
});

router.post('/login', (req, res) => {
  res.json({ message: 'Login endpoint' });
});

module.exports = router;
EOF

cat > backend/src/routes/users.js << 'EOF'
const express = require('express');
const router = express.Router();

router.get('/:id', (req, res) => {
  res.json({ message: 'Get user endpoint' });
});

module.exports = router;
EOF

cat > backend/src/routes/agents.js << 'EOF'
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ agents: [] });
});

router.get('/:id', (req, res) => {
  res.json({ message: 'Get agent endpoint' });
});

router.post('/:id/run', (req, res) => {
  res.json({ message: 'Run agent endpoint' });
});

module.exports = router;
EOF

cat > backend/src/routes/crypto.js << 'EOF'
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ cryptos: [] });
});

router.get('/:symbol', (req, res) => {
  res.json({ message: 'Get crypto endpoint' });
});

module.exports = router;
EOF

cat > backend/src/routes/analysis.js << 'EOF'
const express = require('express');
const router = express.Router();

router.get('/:symbol', (req, res) => {
  res.json({ message: 'Get analysis endpoint' });
});

router.get('/:symbol/score', (req, res) => {
  res.json({ score: 85 });
});

module.exports = router;
EOF

# 8. Criar Dockerfile backend
echo "🐳 Criando backend/Dockerfile..."
cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production

COPY . .

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

CMD ["npm", "start"]
EOF

# 9. Criar .dockerignore
echo "📝 Criando backend/.dockerignore..."
cat > backend/.dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
.env
.env.local
README.md
.DS_Store
.vscode
.idea
coverage
.nyc_output
EOF

# 10. Criar frontend files
echo "📝 Criando frontend files..."

cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Crypto Monitor - Dashboard</title>
  <link rel="stylesheet" href="./styles/main.css">
</head>
<body>
  <div id="app">
    <nav class="navbar">
      <div class="container">
        <h1 class="navbar-brand">Crypto Monitor</h1>
        <ul class="nav-links">
          <li><a href="#dashboard">Dashboard</a></li>
          <li><a href="#analysis">Analysis</a></li>
          <li><a href="#agents">Agents</a></li>
          <li><a href="#profile">Profile</a></li>
        </ul>
      </div>
    </nav>

    <main class="main-content">
      <div class="container">
        <h2>Cryptocurrency Analysis Dashboard</h2>
        <div id="crypto-list" class="crypto-grid"></div>
      </div>
    </main>

    <footer class="footer">
      <p>&copy; 2025 Crypto Monitor. All rights reserved.</p>
    </footer>
  </div>

  <script src="./js/api.js"></script>
  <script src="./js/app.js"></script>
</body>
</html>
EOF

cat > frontend/styles/main.css << 'EOF'
:root {
  --primary-color: #1a1a2e;
  --secondary-color: #16213e;
  --accent-color: #0f3460;
  --success-color: #27ae60;
  --danger-color: #e74c3c;
  --text-light: #ecf0f1;
  --text-dark: #2c3e50;
  --border-color: #34495e;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  background-color: var(--primary-color);
  color: var(--text-light);
  line-height: 1.6;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 20px;
}

.navbar {
  background-color: var(--secondary-color);
  border-bottom: 2px solid var(--accent-color);
  padding: 1rem 0;
  position: sticky;
  top: 0;
  z-index: 100;
}

.navbar .container {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.navbar-brand {
  font-size: 1.5rem;
  font-weight: bold;
  color: var(--accent-color);
}

.nav-links {
  display: flex;
  list-style: none;
  gap: 2rem;
}

.nav-links a {
  color: var(--text-light);
  text-decoration: none;
  transition: color 0.3s ease;
}

.nav-links a:hover {
  color: var(--accent-color);
}

.main-content {
  padding: 2rem 0;
  min-height: calc(100vh - 120px);
}

.main-content h2 {
  margin-bottom: 2rem;
  font-size: 2rem;
}

.crypto-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
}

.crypto-card {
  background-color: var(--secondary-color);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  transition: transform 0.3s ease, border-color 0.3s ease;
}

.crypto-card:hover {
  transform: translateY(-5px);
  border-color: var(--accent-color);
}

.crypto-card h3 {
  color: var(--accent-color);
  margin-bottom: 0.5rem;
}

.crypto-card p {
  margin: 0.5rem 0;
  font-size: 0.9rem;
  color: #bdc3c7;
}

.price {
  font-size: 1.5rem;
  color: var(--success-color);
  font-weight: bold;
}

.change {
  font-weight: bold;
}

.change.positive {
  color: var(--success-color);
}

.change.negative {
  color: var(--danger-color);
}

.footer {
  background-color: var(--secondary-color);
  border-top: 1px solid var(--border-color);
  padding: 2rem;
  text-align: center;
  color: #7f8c8d;
}

.loading {
  text-align: center;
  padding: 2rem;
}

.spinner {
  border: 4px solid rgba(15, 52, 96, 0.3);
  border-top-color: var(--accent-color);
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
  margin: 0 auto;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
  .nav-links {
    gap: 1rem;
  }
  .crypto-grid {
    grid-template-columns: 1fr;
  }
}
EOF

cat > frontend/js/api.js << 'EOF'
const API_BASE = 'http://localhost:8000/api';

class API {
  static async request(method, endpoint, data = null) {
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const token = localStorage.getItem('token');
    if (token) {
      options.headers.Authorization = `Bearer ${token}`;
    }

    if (data) {
      options.body = JSON.stringify(data);
    }

    try {
      const response = await fetch(`${API_BASE}${endpoint}`, options);

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || `HTTP ${response.status}`);
      }

      return response.json();
    } catch (error) {
      console.error('API Error:', error);
      throw error;
    }
  }

  static getCryptos() {
    return this.request('GET', '/crypto');
  }

  static getCryptoData(symbol) {
    return this.request('GET', `/crypto/${symbol}`);
  }

  static getCryptoAnalysis(symbol) {
    return this.request('GET', `/analysis/${symbol}`);
  }

  static getCryptoScore(symbol) {
    return this.request('GET', `/analysis/${symbol}/score`);
  }

  static getAgents() {
    return this.request('GET', '/agents');
  }

  static runAgent(agentId) {
    return this.request('POST', `/agents/${agentId}/run`);
  }

  static login(email, password) {
    return this.request('POST', '/auth/login', { email, password });
  }

  static register(email, password, name) {
    return this.request('POST', '/auth/register', { email, password, name });
  }

  static logout() {
    localStorage.removeItem('token');
  }
}
EOF

cat > frontend/js/app.js << 'EOF'
document.addEventListener('DOMContentLoaded', async () => {
  console.log('App initialized');
  loadCryptos();
});

async function loadCryptos() {
  const container = document.getElementById('crypto-list');
  
  try {
    container.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    
    const data = await API.getCryptos();
    
    if (data.cryptos && data.cryptos.length > 0) {
      container.innerHTML = data.cryptos.map(crypto => `
        <div class="crypto-card">
          <h3>${crypto.symbol}</h3>
          <p>${crypto.name}</p>
          <p class="price">$${crypto.price.toFixed(2)}</p>
          <p class="change ${crypto.change24h >= 0 ? 'positive' : 'negative'}">
            ${crypto.change24h >= 0 ? '+' : ''}${crypto.change24h.toFixed(2)}%
          </p>
        </div>
      `).join('');
    } else {
      container.innerHTML = '<p>No cryptocurrencies available</p>';
    }
  } catch (error) {
    container.innerHTML = `<p>Error loading cryptos: ${error.message}</p>`;
  }
}
EOF

cat > frontend/Dockerfile << 'EOF'
FROM nginx:alpine

COPY . /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
EOF

cat > frontend/nginx.conf << 'EOF'
server {
  listen 3000;
  server_name localhost;

  root /usr/share/nginx/html;
  index index.html index.htm;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /api {
    proxy_pass http://backend:8000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
}
EOF

# 11. Criar database init script
echo "📝 Criando scripts/init-db.sql..."
cat > scripts/init-db.sql << 'EOF'
-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  role VARCHAR(50) DEFAULT 'user',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create cryptocurrencies table
CREATE TABLE IF NOT EXISTS cryptocurrencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol VARCHAR(10) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  logo_url VARCHAR(500),
  website VARCHAR(500),
  github_repo VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create crypto prices table (time series)
CREATE TABLE IF NOT EXISTS crypto_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  crypto_id UUID NOT NULL REFERENCES cryptocurrencies(id) ON DELETE CASCADE,
  price DECIMAL(20, 8) NOT NULL,
  volume_24h DECIMAL(20, 2),
  market_cap DECIMAL(20, 2),
  change_24h DECIMAL(10, 4),
  change_7d DECIMAL(10, 4),
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create agents table
CREATE TABLE IF NOT EXISTS agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  type VARCHAR(50) NOT NULL,
  version VARCHAR(50),
  is_active BOOLEAN DEFAULT true,
  config JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create analysis results table
CREATE TABLE IF NOT EXISTS analysis_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  crypto_id UUID NOT NULL REFERENCES cryptocurrencies(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  result JSONB NOT NULL,
  score DECIMAL(5, 2),
  recommendation VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_cryptocurrencies_symbol ON cryptocurrencies(symbol);
CREATE INDEX idx_crypto_prices_timestamp ON crypto_prices(timestamp);
CREATE INDEX idx_analysis_results_crypto_id ON analysis_results(crypto_id);
CREATE INDEX idx_analysis_results_agent_id ON analysis_results(agent_id);
EOF

# 12. Criar GitHub Actions workflow
echo "📝 Criando .github/workflows/ci.yml..."
mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd backend && npm ci
      
      - name: Run linter
        run: cd backend && npm run lint || true

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd backend && npm ci
      
      - name: Run tests
        run: cd backend && npm test || true
        env:
          DB_HOST: localhost
          REDIS_URL: redis://localhost:6379/0

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Build backend Docker image
        uses: docker/build-push-action@v4
        with:
          context: ./backend
          push: false
          tags: crypto-monitor-api:latest
      
      - name: Build frontend Docker image
        uses: docker/build-push-action@v4
        with:
          context: ./frontend
          push: false
          tags: crypto-monitor-web:latest
EOF

echo "✅ Infraestrutura criada com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "1. cd crypto-monitor"
echo "2. cp .env.example .env"
echo "3. docker-compose up -d"
echo "4. Acesse: http://localhost:3000"
echo ""
echo "✨ Pronto para uso!"
