#!/bin/bash
# Nightcrawler VPS Setup — Run this on your LOCAL machine
# Usage: bash setup-vps.sh
# Requires: ssh access to root@89.167.81.3

set -euo pipefail

VPS="root@89.167.81.3"
NC_HOME="/home/nightcrawler"

echo "=== Step 1: Create nightcrawler user and directories ==="
ssh $VPS bash -s <<'REMOTE'
set -euo pipefail

# Create user if not exists
if ! id nightcrawler &>/dev/null; then
    adduser --disabled-password --gecos "" nightcrawler
    echo "Created nightcrawler user"
else
    echo "nightcrawler user already exists"
fi

# Nightcrawler state repo
mkdir -p /home/nightcrawler/nightcrawler/{config,sessions,templates,docs}

# Projects directory
mkdir -p /home/nightcrawler/projects

# Initialize clout as a git repo
if [ ! -d /home/nightcrawler/projects/clout/.git ]; then
    sudo -u nightcrawler git init /home/nightcrawler/projects/clout
    cd /home/nightcrawler/projects/clout
    sudo -u nightcrawler git config user.name "Nightcrawler"
    sudo -u nightcrawler git config user.email "nightcrawler@local"
    echo "Initialized clout repo"
else
    echo "clout repo already exists"
fi

chown -R nightcrawler:nightcrawler /home/nightcrawler/
echo "Directories created"
REMOTE

echo ""
echo "=== Step 2: Copy Nightcrawler spec files ==="

# Nightcrawler state repo
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/SPEC.md $VPS:$NC_HOME/nightcrawler/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/RULES.md $VPS:$NC_HOME/nightcrawler/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/TERMS.md $VPS:$NC_HOME/nightcrawler/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/ESCALATION.md $VPS:$NC_HOME/nightcrawler/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/README.md $VPS:$NC_HOME/nightcrawler/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/memory.md $VPS:$NC_HOME/nightcrawler/

# Config
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/config/openclaw.yaml $VPS:$NC_HOME/nightcrawler/config/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/config/budget.yaml $VPS:$NC_HOME/nightcrawler/config/
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/config/models.yaml $VPS:$NC_HOME/nightcrawler/config/

# Templates
scp /sessions/relaxed-jolly-ritchie/mnt/nightcrawler/templates/* $VPS:$NC_HOME/nightcrawler/templates/

echo "Nightcrawler files copied"

echo ""
echo "=== Step 3: Copy Clout project files ==="

scp /sessions/relaxed-jolly-ritchie/mnt/clutch/GLOBAL_PLAN.md $VPS:$NC_HOME/projects/clout/
scp /sessions/relaxed-jolly-ritchie/mnt/clutch/TASK_QUEUE.md $VPS:$NC_HOME/projects/clout/
scp /sessions/relaxed-jolly-ritchie/mnt/clutch/PROGRESS.md $VPS:$NC_HOME/projects/clout/
scp /sessions/relaxed-jolly-ritchie/mnt/clutch/BLOCKERS.md $VPS:$NC_HOME/projects/clout/
scp /sessions/relaxed-jolly-ritchie/mnt/clutch/memory.md $VPS:$NC_HOME/projects/clout/
scp /sessions/relaxed-jolly-ritchie/mnt/clutch/RESEARCH.md $VPS:$NC_HOME/projects/clout/

echo "Clout files copied"

echo ""
echo "=== Step 4: Fix ownership and initial commit ==="
ssh $VPS bash -s <<'REMOTE'
set -euo pipefail

chown -R nightcrawler:nightcrawler /home/nightcrawler/

# Initial commit in clout repo
cd /home/nightcrawler/projects/clout
sudo -u nightcrawler git add -A
sudo -u nightcrawler git commit -m "Initial commit: Clout MVP plan + task queue" || echo "Nothing to commit"
echo "Initial commit done"
REMOTE

echo ""
echo "=== Step 5: Install system dependencies ==="
ssh $VPS bash -s <<'REMOTE'
set -euo pipefail

apt-get update -qq

# Podman (for containers)
if ! command -v podman &>/dev/null; then
    apt-get install -y -qq podman
    echo "Podman installed"
else
    echo "Podman already installed"
fi

# Node.js (for frontend tasks later)
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs
    npm install -g pnpm
    echo "Node.js + pnpm installed"
else
    echo "Node.js already installed: $(node --version)"
fi

echo "System deps done"
REMOTE

echo ""
echo "=== Step 6: Install Foundry (as nightcrawler) ==="
ssh $VPS bash -s <<'REMOTE'
set -euo pipefail

if sudo -u nightcrawler bash -c "command -v forge" &>/dev/null; then
    echo "Foundry already installed"
else
    sudo -u nightcrawler bash -c 'curl -L https://foundry.paradigm.xyz | bash'
    sudo -u nightcrawler bash -c 'source /home/nightcrawler/.bashrc && /home/nightcrawler/.foundry/bin/foundryup'
    echo "Foundry installed"
fi
REMOTE

echo ""
echo "=== Step 7: Create .env template ==="
ssh $VPS bash -s <<'REMOTE'
set -euo pipefail

if [ ! -f /home/nightcrawler/.env ]; then
    cat > /home/nightcrawler/.env <<'ENV'
# Nightcrawler Environment — fill in your keys
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_WHATSAPP_FROM=whatsapp:+
TWILIO_WHATSAPP_TO=whatsapp:+
ENV
    chown nightcrawler:nightcrawler /home/nightcrawler/.env
    chmod 600 /home/nightcrawler/.env
    echo "Created .env template — YOU MUST FILL IN THE KEYS"
else
    echo ".env already exists"
fi
REMOTE

echo ""
echo "=== Step 8: Validate setup ==="
ssh $VPS bash -s <<'REMOTE'
set -euo pipefail

echo "--- File structure ---"
echo "Nightcrawler:"
ls /home/nightcrawler/nightcrawler/
echo ""
echo "Config:"
ls /home/nightcrawler/nightcrawler/config/
echo ""
echo "Clout project:"
ls /home/nightcrawler/projects/clout/
echo ""
echo "Git log:"
cd /home/nightcrawler/projects/clout && sudo -u nightcrawler git log --oneline
echo ""
echo "--- Tools ---"
echo "Podman: $(podman --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "Node: $(node --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "Forge: $(sudo -u nightcrawler bash -c '/home/nightcrawler/.foundry/bin/forge --version' 2>/dev/null || echo 'NOT INSTALLED')"
echo ""
echo "--- .env status ---"
if grep -q "ANTHROPIC_API_KEY=$" /home/nightcrawler/.env; then
    echo "⚠️  .env keys are EMPTY — fill them in: nano /home/nightcrawler/.env"
else
    echo "✓ .env has values"
fi
REMOTE

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. SSH in:  ssh root@89.167.81.3"
echo "  2. Fill keys:  nano /home/nightcrawler/.env"
echo "  3. Validate Codex:  sudo -u nightcrawler bash -c 'source ~/.bashrc && codex -p \"Review: function add(a,b){return a+b}\"'"
echo "  4. Then: dry run NC-001"
echo ""
