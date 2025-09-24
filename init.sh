#!/bin/bash

# YOLOsandbox: Simple Sandbox - Unified Initialization Script
# Enhanced with auto-detection for local template or GitHub source
# Usage: unified_init.sh [OPTIONS] [TARGET_DIR] [TEMPLATE_DIR]
#    or: curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/unified_init.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# CONFIGURATION - Easily configurable
# ============================================
REPO_BASE="https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/refs/heads/main"

# Feature flags with defaults
NON_INTERACTIVE=0
RUN_TESTS=0
VERBOSE=0
KEEP_RUNNING=1
SHOW_HELP=0

# Directory arguments
TARGET_DIR=""
TEMPLATE_DIR=""
USE_LOCAL_TEMPLATE=0

# Script information
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ============================================
# GITHUB REPOSITORY CONFIGURATION
# Supports both public and private repositories
# ============================================
# If a GITHUB_TOKEN is provided (via .env file or environment variable),
# the script will use it for authentication to access private repositories.
# Otherwise, it assumes the repository is public.

# Load .env file if it exists (for private repo support)
CURL_AUTH=""
if [ -f .env ]; then
    echo "📄 Found .env file, checking for GitHub token..."
    set -a  # automatically export all variables
    source .env
    set +a

    if [ -n "$GITHUB_TOKEN" ]; then
        echo "🔐 GitHub token detected, configuring private repository access..."
        CURL_AUTH="-H \"Authorization: token ${GITHUB_TOKEN}\""
    fi
elif [ -n "$GITHUB_TOKEN" ]; then
    # Token might be set as environment variable directly
    echo "🔐 GitHub token found in environment, configuring private repository access..."
    CURL_AUTH="-H \"Authorization: token ${GITHUB_TOKEN}\""
else
    echo "📂 No GitHub token found, assuming public repository..."
fi

# Usage function
usage() {
    cat << EOF
Usage: curl -sSL $REPO_BASE/unified_init.sh | bash -s -- [OPTIONS] [TARGET_DIR] [TEMPLATE_DIR]
   or: $SCRIPT_NAME [OPTIONS] [TARGET_DIR] [TEMPLATE_DIR]

Initialize a YOLOsandbox Simple Sandbox development environment.
Automatically detects whether to use local template or GitHub source.

ARGUMENTS:
    TARGET_DIR      Directory where the sandbox will be initialized
                    (default: current directory)
    TEMPLATE_DIR    Source template directory for local initialization
                    (if provided and exists: local mode, otherwise: GitHub mode)

OPTIONS:
    -n, --non-interactive     Skip all prompts and use default values
    -t, --run-tests, --test   Automatically run test suite after initialization
    -v, --verbose             Enable verbose output for test execution
    --stop-after-tests        Stop container after tests complete (long-form only)
    -h, --help                Display this help message and exit

EXAMPLES:
    # One-line remote installation from GitHub
    curl -sSL $REPO_BASE/unified_init.sh | bash

    # Remote installation with options
    curl -sSL $REPO_BASE/unified_init.sh | bash -s -- -n -t

    # Local template mode (if ./template exists)
    $SCRIPT_NAME /my/project ./template

    # Auto-detect mode (GitHub if no local template found)
    $SCRIPT_NAME /my/project

    # Full automation: non-interactive, run tests, then stop
    $SCRIPT_NAME -n -t --stop-after-tests /tmp/test-sandbox

SOURCE DETECTION:
    - If TEMPLATE_DIR is provided and exists: Uses local template files
    - Otherwise: Downloads from GitHub repository
    - Local mode validates template has required Docker files
    - GitHub mode uses authentication if GITHUB_TOKEN is available

NOTES:
    - Requires Docker and Docker Compose to be installed
    - Creates .env file with project name and user IDs
    - Supports VS Code Dev Containers
    - Includes test suite for verification

For more information, visit: https://github.com/YOLOsandbox/simple-sandbox
EOF
}

# Parse command line arguments
parse_arguments() {
    local positional_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                SHOW_HELP=1
                shift
                ;;
            -n|--non-interactive)
                NON_INTERACTIVE=1
                shift
                ;;
            -t|--run-tests|--test)
                RUN_TESTS=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --stop-after-tests)
                KEEP_RUNNING=0
                shift
                ;;
            -*)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    # Process positional arguments
    if [ ${#positional_args[@]} -ge 1 ]; then
        TARGET_DIR="${positional_args[0]}"
    fi
    if [ ${#positional_args[@]} -ge 2 ]; then
        TEMPLATE_DIR="${positional_args[1]}"
    fi

    # Set defaults if not provided
    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$(pwd)"
    fi
}

# Detect source mode (local template vs GitHub)
detect_source_mode() {
    if [ -n "$TEMPLATE_DIR" ] && [ -d "$TEMPLATE_DIR" ]; then
        # Template directory provided and exists - try local mode
        if [ -f "$TEMPLATE_DIR/docker/Dockerfile" ] && [ -f "$TEMPLATE_DIR/docker/docker-compose.yml" ]; then
            USE_LOCAL_TEMPLATE=1
            TEMPLATE_DIR="$(cd "$TEMPLATE_DIR" && pwd)"
            echo -e "${BLUE}🏠 Local template mode detected${NC}"
            echo -e "${BLUE}Template: ${NC}$TEMPLATE_DIR"
        else
            echo -e "${YELLOW}⚠️  Template directory missing required Docker files, falling back to GitHub mode${NC}"
            USE_LOCAL_TEMPLATE=0
        fi
    else
        # No template directory or doesn't exist - use GitHub mode
        USE_LOCAL_TEMPLATE=0
        echo -e "${BLUE}🌐 GitHub mode detected${NC}"
        echo -e "${BLUE}Repository: ${NC}$REPO_BASE"
    fi
}

# Check prerequisites
check_prerequisites() {
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check if docker-compose is installed
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
        echo "Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# Setup files from GitHub repository (unified approach)
setup_from_github() {
    local target="$1"

    echo "📥 Downloading repository from GitHub..."

    # Parse GitHub details from REPO_BASE
    local github_path=$(echo "$REPO_BASE" | sed 's|https://raw.githubusercontent.com/||')

    # Handle both URL formats (with and without refs/heads/)
    if echo "$github_path" | grep -q "refs/heads/"; then
        github_path=$(echo "$github_path" | sed 's|/refs/heads/|/|')
    fi

    local owner=$(echo "$github_path" | cut -d'/' -f1)
    local repo=$(echo "$github_path" | cut -d'/' -f2)
    local branch=$(echo "$github_path" | cut -d'/' -f3-)  # Get everything after repo as branch

    # Determine tarball URL based on auth
    local tarball_url
    if [ -n "$GITHUB_TOKEN" ]; then
        # Use API endpoint for authenticated requests
        tarball_url="https://api.github.com/repos/${owner}/${repo}/tarball/${branch}"
    else
        # Use direct archive URL for public repos
        tarball_url="https://github.com/${owner}/${repo}/archive/${branch}.tar.gz"
    fi

    echo "📦 Repository: ${owner}/${repo} (branch: ${branch})"

    # Create temp directory in /tmp
    local temp_dir=$(mktemp -d /tmp/sandbox-init-XXXXXX)
    local tarball_path="${temp_dir}/repo.tar.gz"

    # Download tarball
    echo "📥 Downloading repository archive..."
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -sSL -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            -L -o "$tarball_path" "$tarball_url" 2>/dev/null || {
            echo -e "${RED}❌ Failed to download repository archive${NC}"
            rm -rf "$temp_dir"
            exit 1
        }
    else
        curl -sSL -L -o "$tarball_path" "$tarball_url" 2>/dev/null || {
            echo -e "${RED}❌ Failed to download repository archive${NC}"
            rm -rf "$temp_dir"
            exit 1
        }
    fi

    # Check if download was successful
    if [ ! -f "$tarball_path" ] || [ ! -s "$tarball_path" ]; then
        echo -e "${RED}❌ Failed to download repository archive${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Extract archive
    echo "📦 Extracting repository files..."
    tar -xzf "$tarball_path" -C "$temp_dir" 2>/dev/null || {
        echo -e "${RED}❌ Failed to extract repository archive${NC}"
        rm -rf "$temp_dir"
        exit 1
    }

    # Get the actual directory name in the tarball
    local archive_root=$(tar -tzf "$tarball_path" 2>/dev/null | head -1 | cut -d'/' -f1)
    local extract_dir="${temp_dir}/${archive_root}"

    # Copy required files to target
    echo "📥 Setting up project files..."

    # Docker directory (required)
    if [ -d "${extract_dir}/docker" ]; then
        cp -r "${extract_dir}/docker/"* "$target/docker/" 2>/dev/null || {
            echo -e "${RED}❌ Failed to copy docker files${NC}"
            rm -rf "$temp_dir"
            exit 1
        }
        echo "✅ Docker configuration files"
    else
        echo -e "${RED}❌ No docker directory found in repository${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Tests directory (copy to docker/tests)
    if [ -d "${extract_dir}/tests" ]; then
        mkdir -p "$target/docker/tests"
        cp -r "${extract_dir}/tests/"* "$target/docker/tests/" 2>/dev/null || true
        find "$target/docker/tests" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
        local test_count=$(find "$target/docker/tests" -type f | wc -l)
        echo "✅ Test suite (${test_count} files)"
    fi

    # .devcontainer directory (optional)
    if [ -d "${extract_dir}/.devcontainer" ]; then
        cp -r "${extract_dir}/.devcontainer/"* "$target/.devcontainer/" 2>/dev/null || true
        echo "✅ VS Code Dev Container configuration"
    fi

    # .dockerignore (optional)
    if [ -f "${extract_dir}/.dockerignore" ]; then
        cp "${extract_dir}/.dockerignore" "$target/.dockerignore" 2>/dev/null || true
    fi

    # claude-data directory (optional)
    if [ -d "${extract_dir}/claude-data" ]; then
        [ -f "${extract_dir}/claude-data/.gitignore" ] && \
            cp "${extract_dir}/claude-data/.gitignore" "$target/claude-data/.gitignore" 2>/dev/null || true
        [ -f "${extract_dir}/claude-data/README.md" ] && \
            cp "${extract_dir}/claude-data/README.md" "$target/claude-data/README.md" 2>/dev/null || true
    fi

    # Clean up temp directory
    rm -rf "$temp_dir"

    echo "✅ Repository files successfully downloaded and configured"
}

# Setup files from local template
setup_files_from_local() {
    local target="$1"
    local template="$2"

    # Safety check to avoid self-copy
    if [ "$template" = "$target" ]; then
        echo -e "${YELLOW}⚠️  Template and target directories are the same, skipping file copy${NC}"
        return 0
    fi

    echo "📥 Copying files from template..."

    # Docker files (required)
    cp "$template/docker/Dockerfile" docker/Dockerfile
    cp "$template/docker/docker-compose.yml" docker/docker-compose.yml

    # Copy tests to docker/tests if they exist
    if [ -d "$template/tests" ]; then
        mkdir -p docker/tests
        cp -r "$template/tests/"* docker/tests/ 2>/dev/null || true
        find docker/tests -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
        local test_count=$(find docker/tests -type f | wc -l)
        echo "✅ Test suite (${test_count} files) copied to docker/tests"
    elif [ -d "$template/docker/tests" ]; then
        # Tests might already be in docker/tests in template
        mkdir -p docker/tests
        cp -r "$template/docker/tests/"* docker/tests/ 2>/dev/null || true
        find docker/tests -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
        local test_count=$(find docker/tests -type f | wc -l)
        echo "✅ Test suite (${test_count} files) copied"
    fi

    # Copy VS Code dev container configuration
    if [ -f "$template/.devcontainer/devcontainer.json" ]; then
        cp "$template/.devcontainer/devcontainer.json" .devcontainer/devcontainer.json
        echo "📝 Copied .devcontainer/devcontainer.json for VS Code integration"
    else
        echo -e "${YELLOW}⚠️  No .devcontainer/devcontainer.json found in template${NC}"
    fi

    if [ -f "$template/.dockerignore" ]; then
        cp "$template/.dockerignore" .dockerignore 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠️  No .dockerignore found in template${NC}"
    fi

    if [ -f "$template/claude-data/.gitignore" ]; then
        cp "$template/claude-data/.gitignore" claude-data/.gitignore 2>/dev/null || true
        echo "📝 Copied claude-data/.gitignore"
    fi

    if [ -f "$template/claude-data/README.md" ]; then
        cp "$template/claude-data/README.md" claude-data/README.md 2>/dev/null || true
    fi
}

# Unified file setup function
setup_files() {
    local target="$1"

    if [ $USE_LOCAL_TEMPLATE -eq 1 ]; then
        setup_files_from_local "$target" "$TEMPLATE_DIR"
    else
        setup_from_github "$target"
    fi
}

# Tests are now included in the main setup functions
# No separate test setup needed

# Initialize sandbox
initialize_sandbox() {
    local target="$1"

    # Create target directory if it doesn't exist
    mkdir -p "$target"

    # Resolve absolute path
    target="$(cd "$target" && pwd)"

    echo -e "${GREEN}🚀 Initializing YOLOsandbox: Simple Sandbox${NC}"
    echo -e "${BLUE}Target:   ${NC}$target"
    echo ""

    # Change to target directory
    cd "$target"

    # Check if we're already in a sandbox
    if [ -f "docker/docker-compose.yml" ] && grep -q "simple-sandbox" "docker/docker-compose.yml" 2>/dev/null; then
        if [ $NON_INTERACTIVE -eq 0 ]; then
            echo -e "${YELLOW}⚠️  YOLOsandbox: Simple Sandbox already exists in $target${NC}"
            read -p "Do you want to update it? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 0
            fi
        else
            echo -e "${YELLOW}⚠️  Updating existing sandbox (non-interactive mode)${NC}"
        fi
    fi

    # Create necessary directories
    echo "📁 Creating directory structure..."
    mkdir -p docker
    mkdir -p .devcontainer
    mkdir -p claude-data

    # Setup files based on detected mode
    setup_files "$target"

    # Generate unique YOLOsandbox project name using path hash
    PROJECT_BASE=$(basename "$target" | tr '[:upper:]' '[:lower:]')
    PROJECT_PATH_HASH=$(echo -n "$target" | md5sum | cut -c1-8)
    COMPOSE_PROJECT_NAME="yolosandbox_${PROJECT_BASE}_${PROJECT_PATH_HASH}"
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)

    # Detect host timezone
    HOST_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || \
              readlink /etc/localtime 2>/dev/null | sed 's|/usr/share/zoneinfo/||' || \
              echo "UTC")

    {
        echo "COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"
        echo "UID=${HOST_UID}"
        echo "GID=${HOST_GID}"
        echo "TZ=${HOST_TZ}"
    } > docker/.env
    echo "📝 Created .env with unique project: ${COMPOSE_PROJECT_NAME}"
    echo "🕐 Detected timezone: ${HOST_TZ}"
}

# Run tests
run_tests() {
    local target="$1"
    local verbose_flag=""

    if [ $VERBOSE -eq 1 ]; then
        verbose_flag="--verbose"
    fi

    echo ""
    echo -e "${BLUE}🧪 Preparing to run test suite...${NC}"

    # Check if test scripts exist in docker/tests
    if [ ! -f "$target/docker/tests/run_tests.sh" ]; then
        echo -e "${YELLOW}⚠️  Skipping tests - no test scripts found in docker/tests${NC}"
        return 0
    fi

    # Build and start container
    echo "🔨 Building and starting container..."

    # Use absolute path for docker-compose to avoid working directory issues
    local compose_file="$target/docker/docker-compose.yml"

    # Docker Compose needs to run from the docker directory for proper context
    docker-compose --project-directory "$target/docker" -f "$compose_file" up -d --build || {
        echo -e "${RED}❌ Failed to start container${NC}"
        return 1
    }

    # Wait for container to be ready
    echo "⏳ Waiting for container to be ready..."
    sleep 5

    # Run tests
    echo "🚀 Running test suite..."
    if docker-compose --project-directory "$target/docker" -f "$compose_file" exec -T simple-sandbox bash -c "cd /workspace/docker/tests && ./run_tests.sh $verbose_flag"; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        local test_result=0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        local test_result=1
    fi

    # Stop container if requested
    if [ $KEEP_RUNNING -eq 0 ]; then
        echo "🛑 Stopping container (--stop-after-tests flag)..."
        docker-compose --project-directory "$target/docker" -f "$compose_file" down
    else
        echo -e "${GREEN}✅ Container is running and ready for use${NC}"
    fi

    return $test_result
}

# Display next steps
display_next_steps() {
    local target="$1"

    echo -e "${GREEN}✅ YOLOsandbox: Simple Sandbox initialized successfully in $target!${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Go to the project directory:"
    echo "   cd $target"
    echo ""
    echo "2. Start the sandbox:"
    echo "   docker-compose -f docker/docker-compose.yml up -d"
    echo ""
    echo "3. Enter the sandbox:"
    echo "   docker-compose -f docker/docker-compose.yml exec simple-sandbox bash"
    echo ""
    echo "Or if using VS Code/Cursor:"
    echo "   - Open $target in VS Code/Cursor"
    echo "   - Click 'Reopen in Container' when prompted"
    echo ""

    if [ $RUN_TESTS -eq 0 ]; then
        echo "4. (Optional) Run the test suite to verify everything works:"
        if [ $USE_LOCAL_TEMPLATE -eq 1 ] && [ -d "$TEMPLATE_DIR/tests" ]; then
            echo "   # Test scripts were copied from template"
        else
            echo "   # First, ensure test scripts are available:"
            echo "   # They should have been downloaded automatically"
        fi
        echo "   docker-compose -f $target/docker/docker-compose.yml exec -T simple-sandbox bash -c \\"
        echo "     'cd /workspace/docker/tests && ./run_tests.sh'"
        echo ""
    fi

    echo "The sandbox provides:"
    echo "  • Safe isolated environment for AI agents"
    echo "  • Pre-installed Claude Code and Gemini CLI"
    echo "  • Python 3.11, Node.js v22, and development tools"
    echo "  • Persistent AI conversation history"
    echo ""

    if [ $USE_LOCAL_TEMPLATE -eq 1 ]; then
        echo "Initialized from local template: $TEMPLATE_DIR"
    else
        echo "Learn more: https://github.com/YOLOsandbox/simple-sandbox"
    fi
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"

    # Show help if requested
    if [ $SHOW_HELP -eq 1 ]; then
        usage
        exit 0
    fi

    # Detect source mode (local vs GitHub)
    detect_source_mode

    # Check prerequisites
    check_prerequisites

    # Initialize sandbox
    initialize_sandbox "$TARGET_DIR"

    # Run tests if requested
    if [ $RUN_TESTS -eq 1 ]; then
        if ! run_tests "$TARGET_DIR"; then
            exit 1
        fi
    else
        # Display next steps only if not running tests
        display_next_steps "$TARGET_DIR"
    fi

    exit 0
}

# Execute main function
main "$@"