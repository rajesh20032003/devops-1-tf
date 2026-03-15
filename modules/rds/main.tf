
# ============================================================
# RDS Module — Main
# ============================================================
# Creates:
#   → random_password (SEPARATE for each DB!) ← FIXED!
#   → DB Subnet Group
#   → RDS user-db  (PostgreSQL 16.6)
#   → RDS order-db (PostgreSQL 16.6)
#   → Secrets Manager secret + version (user-db)
#   → Secrets Manager secret + version (order-db)
#
# FIXES applied vs old flat code:
#   ✅ Separate passwords per DB (security!)
#   ✅ recovery_window_in_days = 0 (no restore-secret needed!)
#   ✅ secret_version synced with Terraform password
#   ✅ multi_az controlled by variable (dev=false, prod=true)
# ============================================================

# ── Separate passwords per DB ─────────────────────────────────
# OLD: one shared random_password.db for both!
#      if one DB compromised → both exposed! ❌
#
# NEW: separate password per DB!
#      breach of one doesn't affect other! ✅
resource "random_password" "user_db" {
  length           = 32
  special          = true
  override_special = "!#%^&*()-_=+[]{}|;:,.<>?"
  # removed @ / ' " → break PostgreSQL connection strings!
}

resource "random_password" "order_db" {
  length           = 32
  special          = true
  override_special = "!#%^&*()-_=+[]{}|;:,.<>?"
}

# ── DB Subnet Group ───────────────────────────────────────────
# RDS requires subnet group spanning at least 2 AZs
# Mandatory even for single-AZ RDS!
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  }
}

# ── RDS: User DB ──────────────────────────────────────────────
# Stores: users table (id, name, email)
# App: user-service connects here
# Secret: micro-dash/{env}/user-service/db
resource "aws_db_instance" "user_db" {
  identifier     = "${var.project}-${var.environment}-user-db"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  db_name  = "usersdb"
  username = "appuser"
  password = random_password.user_db.result

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false

  # dev  → false (single AZ, saves cost!)
  # prod → true  (Multi-AZ, auto failover!)
  # Controlled by variable — no code change needed!
  multi_az = var.multi_az

  backup_retention_period = 7
  skip_final_snapshot     = true  # POC only
  deletion_protection     = false # POC only
  apply_immediately       = true

  tags = {
    Name    = "${var.project}-${var.environment}-user-db"
    Service = "user-service"
  }
}

# ── RDS: Order DB ─────────────────────────────────────────────
# Stores: orders table (id, item, quantity, user_id)
# App: order-service connects here
# Secret: micro-dash/{env}/order-service/db
resource "aws_db_instance" "order_db" {
  identifier     = "${var.project}-${var.environment}-order-db"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  db_name  = "ordersdb"
  username = "appuser"
  password = random_password.order_db.result

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false

  multi_az = var.multi_az

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name    = "${var.project}-${var.environment}-order-db"
    Service = "order-service"
  }
}

# ── Secrets Manager: User DB ──────────────────────────────────
# recovery_window_in_days = 0 → IMMEDIATE deletion on destroy!
# OLD: default 7 days → terraform destroy marks for deletion
#      next apply → ResourceExistsException! ❌
# NEW: = 0 → destroy = gone immediately!
#      next apply → creates fresh! ✅
resource "aws_secretsmanager_secret" "user_db" {
  name                    = "${var.project}/${var.environment}/user-service/db"
  description             = "PostgreSQL credentials for user-service"
  recovery_window_in_days = 0

  tags = {
    Service = "user-service"
  }
}

# Secret version stores actual credentials as JSON
# ECS task fetches this at runtime via Secrets Manager API
# App reads: host, port, username, password, dbname
resource "aws_secretsmanager_secret_version" "user_db" {
  secret_id = aws_secretsmanager_secret.user_db.id

  # jsonencode → proper JSON formatting
  # Uses Terraform-generated password → always in sync!
  # OLD: manually ran aws secretsmanager put-secret-value
  #      after terraform apply → mismatch possible! ❌
  # NEW: Terraform manages both RDS password AND secret! ✅
  secret_string = jsonencode({
    username = "appuser"
    password = random_password.user_db.result
    host     = aws_db_instance.user_db.address
    port     = 5432
    dbname   = "usersdb"
    engine   = "postgres"
  })
}

# ── Secrets Manager: Order DB ─────────────────────────────────
resource "aws_secretsmanager_secret" "order_db" {
  name                    = "${var.project}/${var.environment}/order-service/db"
  description             = "PostgreSQL credentials for order-service"
  recovery_window_in_days = 0

  tags = {
    Service = "order-service"
  }
}

resource "aws_secretsmanager_secret_version" "order_db" {
  secret_id = aws_secretsmanager_secret.order_db.id

  secret_string = jsonencode({
    username = "appuser"
    password = random_password.order_db.result
    host     = aws_db_instance.order_db.address
    port     = 5432
    dbname   = "ordersdb"
    engine   = "postgres"
  })
}
