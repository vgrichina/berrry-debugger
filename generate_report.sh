#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RESULTS_DIR="test_results"
REPORT_FILE="$RESULTS_DIR/test_report.html"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📸 BerrryDebugger Test Report Generator${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if test results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo -e "${RED}❌ Test results directory not found. Run tests first.${NC}"
    exit 1
fi

# Count screenshots
SCREENSHOT_COUNT=$(find "$RESULTS_DIR" -name "*.png" | wc -l | tr -d ' ')

if [ "$SCREENSHOT_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ No screenshots found in $RESULTS_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}📊 Found $SCREENSHOT_COUNT screenshots${NC}"
echo -e "${YELLOW}🔨 Generating HTML report...${NC}"

# Generate HTML report
cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BerrryDebugger UI Test Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem 0;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
            font-weight: 300;
        }
        
        .header p {
            font-size: 1.1rem;
            opacity: 0.9;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 1rem;
        }
        
        .summary {
            background: white;
            margin: 2rem 0;
            padding: 1.5rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .summary h2 {
            color: #667eea;
            margin-bottom: 1rem;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-top: 1rem;
        }
        
        .stat-card {
            background: #f8f9ff;
            padding: 1rem;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        
        .stat-number {
            font-size: 2rem;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #666;
            text-transform: uppercase;
            font-size: 0.8rem;
            letter-spacing: 1px;
        }
        
        .test-section {
            background: white;
            margin: 2rem 0;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .test-section h3 {
            background: #667eea;
            color: white;
            padding: 1rem 1.5rem;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .test-section h3::before {
            content: "📱";
            font-size: 1.2rem;
        }
        
        .screenshots-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            padding: 1.5rem;
        }
        
        .screenshot-card {
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .screenshot-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.15);
        }
        
        .screenshot-image {
            width: 100%;
            height: 400px;
            object-fit: contain;
            background: #f8f9fa;
            cursor: pointer;
        }
        
        .screenshot-title {
            padding: 1rem;
            background: white;
            border-top: 1px solid #eee;
        }
        
        .screenshot-title h4 {
            color: #333;
            margin-bottom: 0.5rem;
            font-size: 1rem;
        }
        
        .screenshot-description {
            color: #666;
            font-size: 0.9rem;
        }
        
        .test-badge {
            display: inline-block;
            padding: 0.2rem 0.6rem;
            background: #e3f2fd;
            color: #1976d2;
            border-radius: 15px;
            font-size: 0.8rem;
            font-weight: 500;
            margin-bottom: 0.5rem;
        }
        
        /* Modal for full-size images */
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.9);
        }
        
        .modal-content {
            display: block;
            margin: auto;
            max-width: 90%;
            max-height: 90%;
            margin-top: 2%;
        }
        
        .close {
            position: absolute;
            top: 15px;
            right: 35px;
            color: #f1f1f1;
            font-size: 40px;
            font-weight: bold;
            cursor: pointer;
        }
        
        .close:hover {
            color: #bbb;
        }
        
        .footer {
            text-align: center;
            padding: 2rem;
            color: #666;
            font-size: 0.9rem;
        }
        
        @media (max-width: 768px) {
            .screenshots-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .stats {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1>🍇 BerrryDebugger</h1>
            <p>UI Test Report & Screenshot Gallery</p>
        </div>
    </div>

    <div class="container">
        <div class="summary">
            <h2>📊 Test Summary</h2>
            <p>Generated on: <strong id="report-date"></strong></p>
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number" id="total-screenshots">0</div>
                    <div class="stat-label">Screenshots</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="test-suites">3</div>
                    <div class="stat-label">Test Suites</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">✅</div>
                    <div class="stat-label">Status</div>
                </div>
            </div>
        </div>

EOF

# Function to categorize screenshots
categorize_screenshot() {
    local clean_name="$1"
    if [[ "$clean_name" == *"launch"* || "$clean_name" == *"navigation"* || "$clean_name" == *"stability"* ]]; then
        echo "App Launch & Navigation"
    elif [[ "$clean_name" == *"devtools"* || "$clean_name" == *"elements"* || "$clean_name" == *"console"* || "$clean_name" == *"network"* || "$clean_name" == *"tabs"* ]]; then
        echo "Developer Tools"
    elif [[ "$clean_name" == *"scheme"* || "$clean_name" == *"url"* ]]; then
        echo "URL Schemes"
    elif [[ "$clean_name" == *"json"* || "$clean_name" == *"html"* || "$clean_name" == *"example"* || "$clean_name" == *"complex"* || "$clean_name" == *"multiple"* ]]; then
        echo "Content Loading"
    else
        echo "Other"
    fi
}

# Function to get description
get_description() {
    local clean_name="$1"
    case "$clean_name" in
        *launch*) echo "Basic app launch and UI elements" ;;
        *navigation*) echo "Navigation controls and URL handling" ;;
        *stability*) echo "App stability and performance tests" ;;
        *devtools*) echo "Developer tools modal and functionality" ;;
        *scheme*) echo "URL scheme handling and external links" ;;
        *network*) echo "Network monitoring and request capture" ;;
        *json*) echo "JSON data loading and display" ;;
        *html*) echo "HTML page rendering and content" ;;
        *example*) echo "Example page loads and interactions" ;;
        *tabs*) echo "Tab switching and interface navigation" ;;
        *complex*) echo "Complex page interactions" ;;
        *multiple*) echo "Multiple URL and load testing" ;;
        *special*) echo "Special characters and edge cases" ;;
        *close*) echo "Modal closing and cleanup" ;;
        *console*) echo "Console tab functionality" ;;
        *elements*) echo "Elements tab and DOM inspection" ;;
        *) echo "UI test screenshot" ;;
    esac
}

# Generate sections for each category
generate_category() {
    local category="$1"
    local screenshots=""
    
    # Collect screenshots for this category
    for screenshot in "$RESULTS_DIR"/*.png; do
        if [ -f "$screenshot" ]; then
            filename=$(basename "$screenshot" .png)
            clean_name=${filename#unknown_test_}
            file_category=$(categorize_screenshot "$clean_name")
            
            if [ "$file_category" = "$category" ]; then
                screenshots="$screenshots $screenshot"
            fi
        fi
    done
    
    # Generate section if we have screenshots
    if [ -n "$screenshots" ]; then
        cat >> "$REPORT_FILE" << EOF
        <div class="test-section">
            <h3>$category</h3>
            <div class="screenshots-grid">
EOF
        
        for screenshot in $screenshots; do
            filename=$(basename "$screenshot" .png)
            clean_name=${filename#unknown_test_}
            display_name=$(echo "$clean_name" | tr '_' ' ' | sed 's/\b\w/\U&/g')
            description=$(get_description "$clean_name")
            
            cat >> "$REPORT_FILE" << EOF
                <div class="screenshot-card">
                    <img src="$(basename "$screenshot")" alt="$display_name" class="screenshot-image" onclick="openModal(this)">
                    <div class="screenshot-title">
                        <div class="test-badge">$category</div>
                        <h4>$display_name</h4>
                        <p class="screenshot-description">$description</p>
                    </div>
                </div>
EOF
        done
        
        cat >> "$REPORT_FILE" << EOF
            </div>
        </div>
EOF
    fi
}

# Generate all categories
generate_category "App Launch & Navigation"
generate_category "URL Schemes"
generate_category "Developer Tools"
generate_category "Content Loading"
generate_category "Other"

# Complete the HTML
cat >> "$REPORT_FILE" << 'EOF'
    </div>

    <div class="footer">
        <p>Generated by BerrryDebugger Test Suite • Screenshots captured via XCTest UI Testing</p>
    </div>

    <!-- Modal for full-size images -->
    <div id="imageModal" class="modal">
        <span class="close" onclick="closeModal()">&times;</span>
        <img class="modal-content" id="modalImage">
    </div>

    <script>
        // Set report generation date
        document.getElementById('report-date').textContent = new Date().toLocaleString();

        // Count and display total screenshots
        const screenshots = document.querySelectorAll('.screenshot-image');
        document.getElementById('total-screenshots').textContent = screenshots.length;

        // Modal functionality
        function openModal(img) {
            const modal = document.getElementById('imageModal');
            const modalImg = document.getElementById('modalImage');
            modal.style.display = 'block';
            modalImg.src = img.src;
        }

        function closeModal() {
            document.getElementById('imageModal').style.display = 'none';
        }

        // Close modal when clicking outside the image
        window.onclick = function(event) {
            const modal = document.getElementById('imageModal');
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        }

        // Keyboard navigation
        document.addEventListener('keydown', function(event) {
            if (event.key === 'Escape') {
                closeModal();
            }
        });
    </script>
</body>
</html>
EOF

echo -e "${GREEN}✅ HTML report generated: $REPORT_FILE${NC}"
echo -e "${BLUE}📱 Screenshots: $SCREENSHOT_COUNT${NC}"
echo -e "${YELLOW}🌐 Open file://$PWD/$REPORT_FILE in your browser${NC}"