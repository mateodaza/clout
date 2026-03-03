# Nightcrawler project config — Clout (Solidity/Foundry)
# Sourced by nightcrawler.sh at startup. Override any default variable.

PROJECT_DESC="Solidity/Foundry"
BUILD_CMD="forge build"
TEST_CMD="forge test -v"
BUILD_WALL=120
BUILD_IDLE=60
TEST_WALL=300
TEST_IDLE=120

# Iteration caps — Solidity tasks are complex, give more room
MAX_PLAN_ITERATIONS=3
MAX_IMPL_ITERATIONS=5

# Claude CLI max-turns — scale up as codebase grows
PLAN_MAX_TURNS=20
IMPL_MAX_TURNS=25
