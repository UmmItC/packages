#!/bin/bash

# Package Cleanup Script
# Cleans up build artifacts from PKGBUILD directories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
Package Cleanup Script

Usage: $0 [OPTIONS] [DIRECTORY]

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Show verbose output
    -d, --dry-run   Show what would be deleted without actually deleting
    -a, --all       Clean all package directories recursively
    -f, --force     Force cleanup without confirmation

DIRECTORY:
    Specific package directory to clean (default: current directory)

Examples:
    $0                              # Clean current directory
    $0 pen-packages/pdfid          # Clean specific package
    $0 -a                          # Clean all packages recursively
    $0 -d pen-packages/pdfid       # Dry run for specific package
    $0 -v -f pen-packages/         # Verbose force clean of pen-packages/

EOF
}

# Default options
VERBOSE=false
DRY_RUN=false
CLEAN_ALL=false
FORCE=false
TARGET_DIR="."

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -a|--all)
            CLEAN_ALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Function to check if directory has artifacts without cleaning
check_artifacts() {
    local dir="$1"
    local patterns=(
        "pkg"           # Build package directory
        "src"           # Source extraction directory
        "*.pkg.tar.zst" # Built packages
        "*.pkg.tar.xz"  # Built packages (old format)
        "*.tar.gz"      # Downloaded source archives
        "*.tar.bz2"     # Downloaded source archives
        "*.tar.xz"      # Downloaded source archives
        "*.zip"         # Downloaded source archives
        "*-src"         # Some packages create *-src directories
        "*.log"         # Build logs
        ".makepkg"      # Makepkg temporary files
    )
    
    for pattern in "${patterns[@]}"; do
        local files
        files=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null || true)
        if [[ -n "$files" ]]; then
            return 0  # Found artifacts
        fi
    done
    return 1  # No artifacts found
}

# Function to clean a single directory
clean_directory() {
    local dir="$1"
    local found_artifacts=false
    
    if [[ ! -d "$dir" ]]; then
        print_error "Directory '$dir' does not exist"
        return 1
    fi
    
    print_status "Cleaning directory: $dir"
    
    # List of patterns to clean
    local patterns=(
        "pkg"           # Build package directory
        "src"           # Source extraction directory
        "*.pkg.tar.zst" # Built packages
        "*.pkg.tar.xz"  # Built packages (old format)
        "*.tar.gz"      # Downloaded source archives
        "*.tar.bz2"     # Downloaded source archives
        "*.tar.xz"      # Downloaded source archives
        "*.zip"         # Downloaded source archives
        "*-src"         # Some packages create *-src directories
        "*.log"         # Build logs
        ".makepkg"      # Makepkg temporary files
    )
    
    # Check what exists before cleaning
    for pattern in "${patterns[@]}"; do
        if [[ "$VERBOSE" == true ]] || [[ "$DRY_RUN" == true ]]; then
            local files
            files=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null || true)
            if [[ -n "$files" ]]; then
                found_artifacts=true
                if [[ "$DRY_RUN" == true ]]; then
                    echo "  Would remove: $files"
                elif [[ "$VERBOSE" == true ]]; then
                    echo "  Found: $files"
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$found_artifacts" == false ]]; then
            print_status "  No artifacts found to clean"
        fi
        return 0
    fi
    
    # Perform the actual cleanup
    local cleaned_count=0
    for pattern in "${patterns[@]}"; do
        local files
        files=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null || true)
        if [[ -n "$files" ]]; then
            if [[ "$VERBOSE" == true ]]; then
                echo "  Removing: $files"
            fi
            # Use find with -delete for safer removal
            find "$dir" -maxdepth 1 -name "$pattern" -exec rm -rf {} + 2>/dev/null || true
            ((cleaned_count++))
        fi
    done
    
    if [[ $cleaned_count -gt 0 ]]; then
        print_success "  Cleaned $cleaned_count types of artifacts"
    else
        print_status "  No artifacts found to clean"
    fi
}

# Function to find and clean all PKGBUILD directories
clean_all_packages() {
    print_status "Searching for PKGBUILD directories..."
    
    local pkgbuild_dirs
    pkgbuild_dirs=$(find "$TARGET_DIR" -name "PKGBUILD" -type f -exec dirname {} \; 2>/dev/null | sort)
    
    if [[ -z "$pkgbuild_dirs" ]]; then
        print_warning "No PKGBUILD directories found in $TARGET_DIR"
        return 0
    fi
    
    local dir_count
    dir_count=$(echo "$pkgbuild_dirs" | wc -l)
    print_status "Found $dir_count package directories"
    
    # Check which directories actually have artifacts
    local dirs_with_artifacts=()
    while IFS= read -r dir; do
        if check_artifacts "$dir"; then
            dirs_with_artifacts+=("$dir")
        fi
    done <<< "$pkgbuild_dirs"
    
    if [[ ${#dirs_with_artifacts[@]} -eq 0 ]]; then
        print_success "All directories are already clean!"
        return 0
    fi
    
    print_status "Found artifacts in ${#dirs_with_artifacts[@]} directories"
    
    if [[ "$DRY_RUN" == false ]] && [[ "$FORCE" == false ]]; then
        echo
        echo "Directories with build artifacts to clean:"
        printf '  %s\n' "${dirs_with_artifacts[@]}"
        echo
        read -p "Continue with cleanup? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled"
            return 0
        fi
    fi
    
    local success_count=0
    for dir in "${dirs_with_artifacts[@]}"; do
        if clean_directory "$dir"; then
            ((success_count++))
        fi
    done
    
    print_success "Successfully cleaned $success_count/${#dirs_with_artifacts[@]} directories"
}

# Main execution
main() {
    print_status "Package Cleanup Script"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No files will be deleted"
    fi
    
    if [[ "$CLEAN_ALL" == true ]]; then
        clean_all_packages
    else
        # Check if target directory contains PKGBUILD
        if [[ -f "$TARGET_DIR/PKGBUILD" ]]; then
            clean_directory "$TARGET_DIR"
        elif [[ -d "$TARGET_DIR" ]]; then
            # Look for PKGBUILD in subdirectories
            local pkgbuild_dirs
            pkgbuild_dirs=$(find "$TARGET_DIR" -name "PKGBUILD" -type f -exec dirname {} \; 2>/dev/null | sort)
            
            if [[ -n "$pkgbuild_dirs" ]]; then
                local dir_count
                dir_count=$(echo "$pkgbuild_dirs" | wc -l)
                print_status "Found $dir_count package directories in $TARGET_DIR"
                
                # Check which directories actually have artifacts
                local dirs_with_artifacts=()
                while IFS= read -r dir; do
                    if check_artifacts "$dir"; then
                        dirs_with_artifacts+=("$dir")
                    fi
                done <<< "$pkgbuild_dirs"
                
                if [[ ${#dirs_with_artifacts[@]} -eq 0 ]]; then
                    print_success "All directories are already clean!"
                    return 0
                fi
                
                print_status "Found artifacts in ${#dirs_with_artifacts[@]} directories"
                
                if [[ "$FORCE" == false ]] && [[ "$DRY_RUN" == false ]]; then
                    echo "Directories with build artifacts to clean:"
                    printf '  %s\n' "${dirs_with_artifacts[@]}"
                    echo
                    read -p "Clean these directories? [y/N] " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_status "Cleanup cancelled"
                        exit 0
                    fi
                fi
                
                for dir in "${dirs_with_artifacts[@]}"; do
                    clean_directory "$dir"
                done
            else
                print_warning "No PKGBUILD found in $TARGET_DIR"
                print_status "Use -a/--all flag to search recursively"
            fi
        else
            print_error "Target directory '$TARGET_DIR' does not exist"
            exit 1
        fi
    fi
    
    print_success "Cleanup completed!"
}

main