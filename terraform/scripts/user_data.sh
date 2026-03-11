#!/bin/bash
# ============================================================
# USER DATA — Full bootstrap + app deployment
# ============================================================
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== Starting EC2 bootstrap $(date) ==="

# ── Variables ─────────────────────────────────────────────────
AWS_REGION="ap-south-1"
ECR_REGISTRY="760302898980.dkr.ecr.ap-south-1.amazonaws.com"
USER_SECRET="micro-dash/dev/user-service/db"
ORDER_SECRET="micro-dash/dev/order-service/db"

# ── Update system ─────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y

# ── Install Docker ────────────────────────────────────────────
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# ── Install AWS CLI + psql ────────────────────────────────────
apt-get install -y awscli postgresql-client

# ── Install SSM Agent ─────────────────────────────────────────
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

echo "=== Bootstrap complete — starting app deployment $(date) ==="

# ── Wait for instance profile to be ready ─────────────────────
sleep 30

# ── ECR Login ─────────────────────────────────────────────────
echo "=== Logging into ECR ==="
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# ── Pull images ───────────────────────────────────────────────
echo "=== Pulling images from ECR ==="
IMAGE_TAG="v5.0.5"
docker pull $ECR_REGISTRY/frontend:$IMAGE_TAG
docker pull $ECR_REGISTRY/gateway:$IMAGE_TAG
docker pull $ECR_REGISTRY/user-service:$IMAGE_TAG
docker pull $ECR_REGISTRY/order-service:$IMAGE_TAG

# ── Get DB credentials from Secrets Manager ───────────────────
echo "=== Fetching DB credentials ==="

USER_SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id $USER_SECRET \
  --region $AWS_REGION \
  --query SecretString \
  --output text)

ORDER_SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id $ORDER_SECRET \
  --region $AWS_REGION \
  --query SecretString \
  --output text)

# Parse credentials using python3
USER_DB_HOST=$(echo $USER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
USER_DB_USER=$(echo $USER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
USER_DB_PASS=$(echo $USER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")
USER_DB_NAME=$(echo $USER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['dbname'])")

ORDER_DB_HOST=$(echo $ORDER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
ORDER_DB_USER=$(echo $ORDER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
ORDER_DB_PASS=$(echo $ORDER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")
ORDER_DB_NAME=$(echo $ORDER_SECRET_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['dbname'])")

# ── Create init.sql files ─────────────────────────────────────
echo "=== Creating database tables ==="

cat > /tmp/user-init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES
  ('Alice Johnson', 'alice@example.com'),
  ('Bob Smith', 'bob@example.com'),
  ('Carol White', 'carol@example.com'),
  ('Dave Brown', 'dave@example.com')
ON CONFLICT (email) DO NOTHING;
EOF

cat > /tmp/order-init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  product VARCHAR(100) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO orders (user_id, product, amount, status) VALUES
  (1, 'Laptop', 999.99, 'completed'),
  (2, 'Phone', 599.99, 'pending'),
  (3, 'Tablet', 399.99, 'completed'),
  (4, 'Headphones', 149.99, 'shipped')
ON CONFLICT DO NOTHING;
EOF

# ── Run init.sql on RDS ───────────────────────────────────────
echo "=== Initializing databases ==="

PGPASSWORD=$USER_DB_PASS psql \
  -h $USER_DB_HOST \
  -U $USER_DB_USER \
  -d $USER_DB_NAME \
  -f /tmp/user-init.sql && echo "✅ Users DB initialized"

PGPASSWORD=$ORDER_DB_PASS psql \
  -h $ORDER_DB_HOST \
  -U $ORDER_DB_USER \
  -d $ORDER_DB_NAME \
  -f /tmp/order-init.sql && echo "✅ Orders DB initialized"

# ── Create docker networks ────────────────────────────────────
docker network create frontend 2>/dev/null || true
docker network create backend 2>/dev/null || true

# ── Run containers ────────────────────────────────────────────
echo "=== Starting containers ==="

docker run -d \
  --name user-service \
  --network backend \
  --restart unless-stopped \
  -p 3001:3001 \
  -e DB_SECRET_NAME=$USER_SECRET \
  -e AWS_REGION=$AWS_REGION \
  -e PORT=3001 \
  $ECR_REGISTRY/$PROJECT/user-service:$IMAGE_TAG

docker run -d \
  --name order-service \
  --network backend \
  --restart unless-stopped \
  -p 3002:3002 \
  -e DB_SECRET_NAME=$ORDER_SECRET \
  -e AWS_REGION=$AWS_REGION \
  -e PORT=3002 \
  $ECR_REGISTRY/$PROJECT/order-service:$IMAGE_TAG

docker run -d \
  --name gateway \
  --network backend \
  --restart unless-stopped \
  -p 3000:3000 \
  -e USER_SERVICE_URL=http://user-service:3001 \
  -e ORDER_SERVICE_URL=http://order-service:3002 \
  -e PORT=3000 \
  $ECR_REGISTRY/$PROJECT/gateway:$IMAGE_TAG

# connect gateway to frontend network too
docker network connect frontend gateway

docker run -d \
  --name frontend \
  --network frontend \
  --restart unless-stopped \
  -p 100:80 \
  $ECR_REGISTRY/$PROJECT/frontend:$IMAGE_TAG

# ── Wait and health check ─────────────────────────────────────
echo "=== Waiting for services to start ==="
sleep 20

echo "=== Health checks ==="
curl -f http://localhost:3000/health && echo "✅ Gateway healthy"
curl -f http://localhost:100 && echo "✅ Frontend healthy"

echo "=== App deployment complete $(date) ==="
echo "=== Check /var/log/user-data.log for details ==="