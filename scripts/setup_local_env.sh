#!/bin/bash
# Setup script for Ephemery local development
# Creates a secure local environment with proper file structure

set -e  # Exit on error

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=== Ephemery Local Development Environment Setup ===${NC}"
echo ""

# Determine base directory
read -p "Enter base directory for Ephemery files [$HOME/ephemery]: " BASE_DIR
BASE_DIR=${BASE_DIR:-$HOME/ephemery}

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$BASE_DIR"/{data,logs,secrets,scripts,backups,config}
echo -e "${GREEN}✓${NC} Created directory: $BASE_DIR"
echo -e "${GREEN}✓${NC} Created subdirectories: data, logs, secrets, scripts, backups, config"

# Create environment variable file
ENV_FILE="$BASE_DIR/.env"
echo -e "${YELLOW}Creating environment variable file...${NC}"
cat > "$ENV_FILE" <<EOL
# Environment variables for Ephemery
export EPHEMERY_BASE_DIR="$BASE_DIR"
export EPHEMERY_DATA_DIR="$BASE_DIR/data"
export EPHEMERY_LOGS_DIR="$BASE_DIR/logs"
export EPHEMERY_SECRETS_DIR="$BASE_DIR/secrets"
export EPHEMERY_SCRIPTS_DIR="$BASE_DIR/scripts"
export EPHEMERY_BACKUP_DIR="$BASE_DIR/backups"
export EPHEMERY_CONFIG_DIR="$BASE_DIR/config"
export JWT_SECRET_PATH="$BASE_DIR/config/jwt.hex"
# Uncomment and set if needed:
# export DOCKER_HOST="unix:///var/run/docker.sock"
EOL
echo -e "${GREEN}✓${NC} Created environment file: $ENV_FILE"

# Setup local inventory
echo -e "${YELLOW}Creating local inventory file...${NC}"
if [ -f "inventories/local-inventory.yaml.example" ]; then
    cp "inventories/local-inventory.yaml.example" "inventories/my-local-inventory.yaml"
    # Replace paths with environment variable syntax
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery|{{ lookup('env', 'EPHEMERY_BASE_DIR') | default('$BASE_DIR', true) }}|g" "inventories/my-local-inventory.yaml"
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery/data|{{ lookup('env', 'EPHEMERY_DATA_DIR') | default('$BASE_DIR/data', true) }}|g" "inventories/my-local-inventory.yaml"
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery/secrets|{{ lookup('env', 'EPHEMERY_SECRETS_DIR') | default('$BASE_DIR/secrets', true) }}|g" "inventories/my-local-inventory.yaml"
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery/logs|{{ lookup('env', 'EPHEMERY_LOGS_DIR') | default('$BASE_DIR/logs', true) }}|g" "inventories/my-local-inventory.yaml"
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery/scripts|{{ lookup('env', 'EPHEMERY_SCRIPTS_DIR') | default('$BASE_DIR/scripts', true) }}|g" "inventories/my-local-inventory.yaml"
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery/backups|{{ lookup('env', 'EPHEMERY_BACKUP_DIR') | default('$BASE_DIR/backups', true) }}|g" "inventories/my-local-inventory.yaml"
    sed -i.bak "s|/Users/{{ ansible_user }}/ephemery/jwt.hex|{{ lookup('env', 'JWT_SECRET_PATH') | default('$BASE_DIR/config/jwt.hex', true) }}|g" "inventories/my-local-inventory.yaml"
    rm inventories/*.bak 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Created local inventory: inventories/my-local-inventory.yaml"
else
    echo -e "${RED}✗${NC} Could not find inventories/local-inventory.yaml.example"
fi

# Create validator directories if they don't exist
echo -e "${YELLOW}Setting up validator key directories...${NC}"
mkdir -p "files/validator_keys" "files/passwords"
touch "files/passwords/validators.txt"
chmod 600 "files/passwords/validators.txt"
echo -e "${GREEN}✓${NC} Created validator directories and password file"

# Create a pre-commit hook for security checks
echo -e "${YELLOW}Setting up git pre-commit hook for security checks...${NC}"
if [ -d ".git" ]; then
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit <<EOL
#!/bin/bash
# Pre-commit hook to check for potential secrets

echo "Checking for potential secrets and personal information..."

# Check for hardcoded paths that might be personal
if git diff --cached | grep -E '/Users/[a-zA-Z0-9]+/' > /dev/null; then
    echo "WARNING: Possible hardcoded user paths detected in commit."
    echo "Please use environment variables or templating instead."
    exit 1
fi

# Check for potential secrets
if git diff --cached | grep -E '(password|secret|token|key).*[A-Za-z0-9]{8,}' > /dev/null; then
    echo "WARNING: Possible secrets detected in commit."
    echo "Please review your changes for secrets before committing."
    exit 1
fi

exit 0
EOL
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✓${NC} Created pre-commit hook: .git/hooks/pre-commit"
else
    echo -e "${YELLOW}⚠${NC} Not a git repository - skipping pre-commit hook creation"
fi

# Load environment variables
echo -e "${YELLOW}Loading environment variables...${NC}"
echo "source $ENV_FILE" >> "$BASE_DIR/.bashrc_ephemery"
echo -e "${GREEN}✓${NC} Created environment loader: $BASE_DIR/.bashrc_ephemery"

# Final instructions
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "To load the environment variables, run:"
echo -e "${YELLOW}source $ENV_FILE${NC}"
echo ""
echo -e "Or add the following line to your ~/.bashrc or ~/.zshrc:"
echo -e "${YELLOW}source $BASE_DIR/.bashrc_ephemery${NC}"
echo ""
echo -e "Your local inventory file is at:"
echo -e "${YELLOW}inventories/my-local-inventory.yaml${NC}"
echo ""
echo -e "For secure development practices, please read:"
echo -e "${YELLOW}docs/SECURE_DEVELOPMENT.md${NC}"
echo "" 