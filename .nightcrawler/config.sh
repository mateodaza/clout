# Nightcrawler project config — Clout (Turborepo monorepo)
# Sourced by nightcrawler.sh at startup. Override any default variable.

PROJECT_DESC="Turborepo monorepo: Solidity/Foundry + Next.js 16 + shared types"
INSTALL_CMD="pnpm install"
BUILD_CMD="pnpm turbo build"
TEST_CMD="pnpm turbo build && cd packages/contracts && forge test -v"
WORKDIR=""  # root of repo (turborepo runs from root)
BUILD_WALL=180
BUILD_IDLE=90
TEST_WALL=360
TEST_IDLE=180

# Iteration caps — Solidity tasks are complex, give more room
MAX_PLAN_ITERATIONS=3
MAX_IMPL_ITERATIONS=5
