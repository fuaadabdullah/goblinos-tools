#!/bin/bash

# ForgeGoblinVault Setup Validation Script
# Run this after installing and enabling plugins in Obsidian

echo "🔍 ForgeGoblinVault Setup Validation"
echo "===================================="

VAULT_PATH="/Users/fuaadabdullah/ForgeMonorepo/ForgeGoblinVault"

# Check vault structure
echo "📁 Checking vault structure..."
if [ -d "$VAULT_PATH/.obsidian" ]; then
    echo "✅ .obsidian directory exists"
else
    echo "❌ .obsidian directory missing"
    exit 1
fi

# Check plugin configurations
echo ""
echo "🔧 Checking plugin configurations..."

plugins=("dataview" "templater-obsidian" "obsidian-kanban")
for plugin in "${plugins[@]}"; do
    if [ -d "$VAULT_PATH/.obsidian/plugins/$plugin" ]; then
        echo "✅ $plugin plugin directory exists"
    else
        echo "❌ $plugin plugin directory missing"
    fi
done

# Check custom functions
echo ""
echo "⚙️ Checking custom functions..."
if [ -f "$VAULT_PATH/.obsidian/plugins/templater-obsidian/Scripts/forge-functions.js" ]; then
    echo "✅ Custom Templater functions exist"
    # Check if functions are defined
    if grep -q "calculateKPIStatus" "$VAULT_PATH/.obsidian/plugins/templater-obsidian/Scripts/forge-functions.js"; then
        echo "✅ calculateKPIStatus function found"
    else
        echo "❌ calculateKPIStatus function missing"
    fi
else
    echo "❌ Custom functions file missing"
fi

# Check dashboard
echo ""
echo "📊 Checking intelligent dashboard..."
if [ -f "$VAULT_PATH/📊 Dashboards/Intelligent_Development_Dashboard.md" ]; then
    echo "✅ Intelligent dashboard exists"
    # Check for key features
    if grep -q "dataviewjs" "$VAULT_PATH/📊 Dashboards/Intelligent_Development_Dashboard.md"; then
        echo "✅ DataviewJS queries found"
    else
        echo "❌ DataviewJS queries missing"
    fi
    if grep -q "tp\.file\.create_new" "$VAULT_PATH/📊 Dashboards/Intelligent_Development_Dashboard.md"; then
        echo "✅ Templater quick actions found"
    else
        echo "❌ Templater quick actions missing"
    fi
else
    echo "❌ Intelligent dashboard missing"
fi

# Check templates
echo ""
echo "📝 Checking workflow templates..."
templates=(
    "Workflows/Code_Review_Process_Template.md"
    "Workflows/Deployment_Release_Process_Template.md"
    "Workflows/Feature_Development_Lifecycle_Template.md"
    "Workflows/Knowledge_Management_Template.md"
    "Workflows/Team_Coordination_Framework_Template.md"
    "Workflows/Testing_QA_Workflow_Template.md"
    "Project_Template.md"
    "Daily_Development_Log_Template.md"
)

for template in "${templates[@]}"; do
    if [ -f "$VAULT_PATH/🔄 Workflows/$template" ]; then
        echo "✅ $template exists"
    else
        echo "❌ $template missing"
    fi
done

# Check metrics structure
echo ""
echo "📈 Checking metrics structure..."
if [ -d "$VAULT_PATH/📈 Metrics/ForgeTM" ] && [ -d "$VAULT_PATH/📈 Metrics/GoblinOS" ]; then
    echo "✅ Metrics directories exist"
else
    echo "❌ Metrics directories missing"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Open Obsidian and navigate to ForgeGoblinVault"
echo "2. Go to Settings → Community plugins"
echo "3. Enable: Dataview, Templater, Kanban"
echo "4. Open [[📊 Dashboards/Intelligent Development Dashboard]]"
echo "5. Test the quick actions and automated features"
echo ""
echo "🚀 ForgeGoblinVault is ready for development intelligence!"
