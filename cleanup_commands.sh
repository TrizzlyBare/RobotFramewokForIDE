#!/bin/bash

# Cleanup script for Dynamic Testing System
# Removes obsolete files from NewDevelopment folder

echo "Dynamic Testing System - Cleanup Script"
echo "========================================"

NEWDEV_DIR="/Users/tanakrit/Documents/GitHub/RobotFramewokForIDE/NewDevelopment"

echo "Checking for obsolete files in $NEWDEV_DIR..."

# List of files to remove (obsolete static analysis components)
OBSOLETE_FILES=(
    "AssessmentEngine.robot"
    "SimplifiedWebAssessment.robot"
    "WebTestingFramework.robot" 
    "WebTestingOrchestrator.robot"
    "web_test_config.json"
    "teacher_config.json"
)

# Check which files exist
FOUND_FILES=()
for file in "${OBSOLETE_FILES[@]}"; do
    if [ -f "$NEWDEV_DIR/$file" ]; then
        FOUND_FILES+=("$file")
        echo "  - Found obsolete file: $file"
    fi
done

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo "✅ No obsolete files found. System is clean."
else
    echo ""
    echo "Found ${#FOUND_FILES[@]} obsolete file(s) to remove."
    echo ""
    read -p "Do you want to remove these files? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing obsolete files..."
        for file in "${FOUND_FILES[@]}"; do
            rm "$NEWDEV_DIR/$file"
            echo "  ✅ Removed: $file"
        done
        echo ""
        echo "Cleanup completed successfully!"
    else
        echo "Cleanup cancelled."
        exit 1
    fi
fi

echo ""
echo "Remaining essential files in NewDevelopment/:"
ls -la "$NEWDEV_DIR/" | grep -E "\.(robot|json)$"

echo ""
echo "Essential components:"
echo "  ✅ DynamicTestingFramework.robot - Core execution engine"
echo "  ✅ IntegratedTestRunner.robot - Main orchestrator" 
echo "  ✅ test_definitions/ - JSON lesson configurations"
echo ""
echo "System is ready for dynamic testing!"