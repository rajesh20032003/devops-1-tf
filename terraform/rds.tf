# ============================================================
# RDS PostgreSQL + AWS Secrets Manager (2 AZ - Production Grade)
# ============================================================
# multi_az = true → AWS auto creates standby in AZ2
#                   synchronous replication
#                   auto failover in 60-120s if AZ1 goes down
# Credentials stored in Secrets Manager (never hardcoded!)
# ============================================================

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#%^&*()-_=+[]{}|;:,.<>?"
  # removed @ / ' " → these break PostgreSQL connection strings!
}

# ── DB Subnet Group ───────────────────────────────────────────
# RDS requires subnet group spanning at least 2 AZs
# mandatory even for single-AZ RDS instances
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  }
}

# ── RDS: User DB ──────────────────────────────────────────────
resource "aws_db_instance" "user_db" {
  identifier     = "${var.project}-${var.environment}-user-db"
  engine         = "postgres"
  engine_version = "16.1"
  instance_class = "db.t3.micro"

  db_name  = "usersdb"
  username = "appuser"
  password = random_password.db.result

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # ── 2 AZ CHANGE ──────────────────────────────────────────
  multi_az = true
  # AWS automatically:
  # → creates primary in AZ1
  # → creates standby replica in AZ2
  # → synchronous replication (always in sync!)
  # → auto failover if AZ1 goes down
  # → connection string stays SAME after failover
  # → your app doesn't need to change! ✅
  # ─────────────────────────────────────────────────────────

  backup_retention_period = 7
  skip_final_snapshot     = true   # POC only
  deletion_protection     = false  # POC only
  apply_immediately       = true

  tags = {
    Name    = "${var.project}-${var.environment}-user-db"
    Service = "user-service"
  }
}

# ── RDS: Order DB ─────────────────────────────────────────────
resource "aws_db_instance" "order_db" {
  identifier     = "${var.project}-${var.environment}-order-db"
  engine         = "postgres"
  engine_version = "16.1"
  instance_class = "db.t3.micro"

  db_name  = "ordersdb"
  username = "appuser"
  password = random_password.db.result

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # ── 2 AZ CHANGE ──────────────────────────────────────────
  multi_az = true
  # ─────────────────────────────────────────────────────────

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
resource "aws_secretsmanager_secret" "user_db" {
  name        = "${var.project}/${var.environment}/user-service/db"
  description = "PostgreSQL credentials for user-service"

  tags = {
    Service = "user-service"
  }
}

resource "aws_secretsmanager_secret_version" "user_db" {
  secret_id = aws_secretsmanager_secret.user_db.id

  secret_string = jsonencode({
    username = "appuser"
    password = random_password.db.result
    host     = aws_db_instance.user_db.address
    port     = 5432
    dbname   = "usersdb"
    engine   = "postgres"
  })
}

# ── Secrets Manager: Order DB ─────────────────────────────────
resource "aws_secretsmanager_secret" "order_db" {
  name        = "${var.project}/${var.environment}/order-service/db"
  description = "PostgreSQL credentials for order-service"

  tags = {
    Service = "order-service"
  }
}

resource "aws_secretsmanager_secret_version" "order_db" {
  secret_id = aws_secretsmanager_secret.order_db.id

  secret_string = jsonencode({
    username = "appuser"
    password = random_password.db.result
    host     = aws_db_instance.order_db.address
    port     = 5432
    dbname   = "ordersdb"
    engine   = "postgres"
  })
}

# ── Outputs ───────────────────────────────────────────────────
output "user_db_endpoint" {
  value     = aws_db_instance.user_db.address
  sensitive = true
}

output "order_db_endpoint" {
  value     = aws_db_instance.order_db.address
  sensitive = true
}

output "user_db_secret_name" {
  description = "Pass this as DB_SECRET_NAME env var to user-service"
  value       = aws_secretsmanager_secret.user_db.name
}

output "order_db_secret_name" {
  description = "Pass this as DB_SECRET_NAME env var to order-service"
  value       = aws_secretsmanager_secret.order_db.name
}
