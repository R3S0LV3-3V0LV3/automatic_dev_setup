#!/usr/bin/env bash
# =============================================================================
# 06-database-systems.sh - Automatic Dev Setup
# Purpose: Install, initialise, optimise, and secure PostgreSQL, Redis, and MongoDB.
# Version: 3.0.0
# Dependencies: bash, brew, psql, redis-cli, mongosh
# Criticality: ALPHA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || perl -MCwd=abs_path -le 'print abs_path($ARGV[0])' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"


source "$(dirname "${BASH_SOURCE[0]}")/../lib/automatic-dev-env.sh"

ads_enable_traps
export ADS_FAILURE_CODE="${ADS_FAILURE_CODE:-ADS-M06}"

BREW_PREFIX=""
PG_PREFIX=""
PG_BIN=""
PSQL=""
INITDB=""

ADS_PG_ROLE="automatic_dev"
ADS_PG_DEV_DB="automatic_dev_development"
ADS_PG_TEST_DB="automatic_dev_test"

ensure_brew_formula() {
    local formula="$1"
    local friendly="${2:-$1}"
    local short_name="${formula##*/}"
    if ! brew list --formula "$short_name" >/dev/null 2>&1; then
        log_info "Installing required Homebrew formula: ${friendly}"
        if ! ads_retry "brew install ${formula}" brew install "$formula"; then
            log_error "Failed to install Homebrew dependency '${friendly}'."
            return 1
        fi
    fi
}

initialize_database_paths() {
    BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    if [[ -z "$BREW_PREFIX" ]]; then
        log_error "Unable to determine Homebrew prefix. Ensure Homebrew is installed and accessible."
        exit 1
    fi
    ensure_brew_formula "postgresql@16" "postgresql@16"
    PG_PREFIX="$(brew --prefix postgresql@16 2>/dev/null || true)"
    if [[ -z "$PG_PREFIX" ]]; then
        log_error "postgresql@16 not installed via Homebrew."
        exit 1
    fi
    PG_BIN="${PG_PREFIX}/bin"
    PSQL="${PG_BIN}/psql"
    INITDB="${PG_BIN}/initdb"
}

remove_legacy_postgres_services() {
    local service
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        [[ "$service" == "postgresql@16" ]] && continue
        log_warning "Stopping and uninstalling legacy PostgreSQL service '${service}'."
        brew services stop "$service" >/dev/null 2>&1 || true
        launchctl remove "homebrew.mxcl.${service}" >/dev/null 2>&1 || true
        brew uninstall --force "$service" >/dev/null 2>&1 || log_warning "Unable to uninstall ${service}; manual cleanup may be required."
    done < <(brew list --formula 2>/dev/null | grep -E '^postgresql@' || true)
}

calculate_pg_memory() {
    local total_bytes
    total_bytes=$(sysctl -n hw.memsize)
    local total_mb=$((total_bytes / 1024 / 1024))

    local shared_buffers
    local effective_cache_size
    local work_mem
    local maintenance_work_mem

    if [[ "$ADS_MODE" == "performance" ]]; then
        shared_buffers=$((total_mb / 3))
        effective_cache_size=$((total_mb * 2 / 3))
        work_mem=$((total_mb / 24))
        maintenance_work_mem=$((total_mb / 6))
    else
        shared_buffers=$((total_mb / 4))
        effective_cache_size=$((total_mb / 2))
        work_mem=$((total_mb / 32))
        maintenance_work_mem=$((total_mb / 8))
    fi

    (( shared_buffers < 128 )) && shared_buffers=128
    (( effective_cache_size < 256 )) && effective_cache_size=256
    (( work_mem < 16 )) && work_mem=16
    (( maintenance_work_mem < 64 )) && maintenance_work_mem=64

    printf '%s;%s;%s;%s\n' "$shared_buffers" "$effective_cache_size" "$work_mem" "$maintenance_work_mem"
}

ensure_postgres_role() {
    local role="$1"
    local attributes="$2"
    if ! "$PSQL" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${role}'" | grep -q 1; then
        log_info "Creating PostgreSQL role '${role}'..."
        "$PSQL" -d postgres -c "CREATE ROLE ${role} WITH ${attributes}" >/dev/null 2>&1 || log_warning "Failed to create role '${role}'."
    fi
}

ensure_postgres_database() {
    local database="$1"
    local owner="$2"
    if ! "$PSQL" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${database}'" | grep -q 1; then
        log_info "Creating PostgreSQL database '${database}' owned by ${owner}..."
        "$PSQL" -d postgres -c "CREATE DATABASE ${database} OWNER ${owner}" >/dev/null 2>&1 || log_warning "Failed to create database '${database}'."
    fi
}

init_postgres() {
    local data_dir="${BREW_PREFIX}/var/postgresql@16"
    if [[ -d "$data_dir" && -f "$data_dir/PG_VERSION" ]]; then
        log_info "PostgreSQL data directory present."
    else
        log_info "Initialising PostgreSQL data directory..."
        "$INITDB" --locale=en_US.UTF-8 -E UTF8 "$data_dir"
    fi
    if ! brew services start postgresql@16 >/dev/null 2>&1; then
        log_warning "Failed to start postgresql@16 via brew services; attempting restart."
        brew services restart postgresql@16 >/dev/null 2>&1 || log_error "Unable to manage postgresql@16 service via Homebrew."
    fi
}

wait_for_postgres() {
    local pg_isready="${PG_BIN}/pg_isready"
    if [[ ! -x "$pg_isready" ]]; then
        log_error "pg_isready utility not found at ${pg_isready}"
        return 1
    fi

    local attempt=0
    local max_attempts=40
    while (( attempt < max_attempts )); do
        if "$pg_isready" >/dev/null 2>&1; then
            return 0
        fi
        ((attempt++))
        sleep 2
    done

    log_warning "PostgreSQL did not report ready after ${max_attempts} checks; forcing service restart."
    brew services restart postgresql@16 >/dev/null 2>&1 || log_warning "brew services restart postgresql@16 failed."
    "${PG_BIN}/pg_ctl" -D "${BREW_PREFIX}/var/postgresql@16" start >/dev/null 2>&1 || true

    attempt=0
    max_attempts=30
    while (( attempt < max_attempts )); do
        if "$pg_isready" >/dev/null 2>&1; then
            return 0
        fi
        ((attempt++))
        sleep 2
    done

    log_error "PostgreSQL service did not become ready in time."
    return 1
}

configure_postgres() {
    log_info "Configuring PostgreSQL performance parameters..."
    local values
    IFS=";" read -r shared_buffers effective_cache_size work_mem maintenance_work_mem <<<"$(calculate_pg_memory)"
    local effective_io="200"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        effective_io="0"
    fi

    "$PSQL" -d postgres <<SQL
ALTER SYSTEM SET shared_buffers = '${shared_buffers}MB';
ALTER SYSTEM SET effective_cache_size = '${effective_cache_size}MB';
ALTER SYSTEM SET work_mem = '${work_mem}MB';
ALTER SYSTEM SET maintenance_work_mem = '${maintenance_work_mem}MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = ${effective_io};
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET log_destination = 'stderr';
ALTER SYSTEM SET logging_collector = on;
ALTER SYSTEM SET log_directory = 'log';
ALTER SYSTEM SET log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log';
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();
SQL
}

bootstrap_postgres_databases() {
    log_info "Ensuring PostgreSQL roles and databases..."
    ensure_postgres_role "$ADS_PG_ROLE" "LOGIN CREATEDB CREATEROLE"
    ensure_postgres_database "$ADS_PG_DEV_DB" "$ADS_PG_ROLE"
    ensure_postgres_database "$ADS_PG_TEST_DB" "$ADS_PG_ROLE"
}

configure_redis() {
    ensure_brew_formula "redis" "redis"
    local redis_conf="$BREW_PREFIX/etc/redis.conf"
    ads_ensure_directory "$(dirname "$redis_conf")"
    ads_backup_file "$redis_conf"
    cat > "$redis_conf" <<EOF
bind 127.0.0.1
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised auto
pidfile ${BREW_PREFIX}/var/run/redis.pid
loglevel notice
logfile ""
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dir ${BREW_PREFIX}/var/db/redis/
masterauth ""
requirepass ""
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
maxmemory 1gb
maxmemory-policy allkeys-lru
EOF
    brew services restart redis
}

configure_mongodb() {
    ensure_brew_formula "mongodb-community@7.0" "mongodb-community@7.0"
    local mongo_conf="$BREW_PREFIX/etc/mongod.conf"
    ads_ensure_directory "$(dirname "$mongo_conf")"
    ads_backup_file "$mongo_conf"
    cat > "$mongo_conf" <<EOF
systemLog:
  destination: file
  path: ${BREW_PREFIX}/var/log/mongodb/mongo.log
  logAppend: true

storage:
  dbPath: ${BREW_PREFIX}/var/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1

net:
  port: 27017
  bindIp: 127.0.0.1

processManagement:
  fork: false
  pidFilePath: ${BREW_PREFIX}/var/mongodb/mongod.pid

security:
  authorization: enabled
EOF
    brew services restart mongodb-community@7.0
}

main() {
    log_header "[06] Database Systems"
    log_info "Database configuration mode: ${ADS_MODE}"
    ads_require_command brew "Install Homebrew via module 02"
    initialize_database_paths
    remove_legacy_postgres_services
    init_postgres
    wait_for_postgres
    configure_postgres
    bootstrap_postgres_databases
    configure_redis
    configure_mongodb
    log_success "Database systems configured."
}

main "$@"
