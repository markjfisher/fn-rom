#!/bin/bash

# bas2ssd.sh - Convert BBC Basic files to SSD disk image
# Usage: ./bas2ssd.sh <input_folder> <output_ssd>
# Example: ./bas2ssd.sh ./basfiles ./output.ssd

set -e  # Exit on any error

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_folder> <output_ssd>"
    echo "Example: $0 ./basfiles ./output.ssd"
    exit 1
fi

INPUT_FOLDER="$1"
OUTPUT_SSD="$2"

# Check if input folder exists
if [ ! -d "$INPUT_FOLDER" ]; then
    echo "Error: Input folder '$INPUT_FOLDER' does not exist"
    exit 1
fi

# Check if dfstool is available
if ! command -v dfstool &> /dev/null; then
    echo "Error: dfstool not found in PATH"
    exit 1
fi

# Create temporary directory for tokenized files
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Function to extract filename from first line of BAS file
# Looks for: REM filename: DESIRED_NAME
extract_filename_from_bas() {
    local bas_file="$1"
    local default_name="$2"
    
    # Read first line of the file
    local first_line=$(head -n 1 "$bas_file" 2>/dev/null)
    
    # Check if first line contains "filename:" pattern
    if echo "$first_line" | grep -qi "filename:"; then
        # Extract the filename after "filename:"
        local extracted_name=$(echo "$first_line" | sed -n 's/.*[Ff][Ii][Ll][Ee][Nn][Aa][Mm][Ee]:[[:space:]]*\([^[:space:]]*\).*/\1/p')
        
        if [ -n "$extracted_name" ]; then
            echo "$extracted_name"
            return 0
        fi
    fi
    
    # Fall back to default name
    echo "$default_name"
}

# Find all .bas files in input folder
BAS_FILES=($(find "$INPUT_FOLDER" -name "*.bas" -type f))

if [ ${#BAS_FILES[@]} -eq 0 ]; then
    echo "Error: No .bas files found in '$INPUT_FOLDER'"
    exit 1
fi

echo "Found ${#BAS_FILES[@]} .bas files to process:"
for file in "${BAS_FILES[@]}"; do
    echo "  - $(basename "$file")"
done

# Tokenize all BAS files
echo ""
echo "Tokenizing BAS files..."
TOKENIZED_FILES=()
TOKENIZED_NAMES=()
for bas_file in "${BAS_FILES[@]}"; do
    # Get base filename without extension as fallback
    base_filename=$(basename "$bas_file" .bas)
    
    # Try to extract filename from first line of BAS file
    extracted_name=$(extract_filename_from_bas "$bas_file" "$base_filename")
    
    # Convert to uppercase and ensure it fits 8.3 format
    # BBC Micro filenames are max 7 chars + .BAS (8.3 total)
    if [ ${#extracted_name} -gt 7 ]; then
        extracted_name="${extracted_name:0:7}"
        echo "  Warning: Filename truncated to fit 8.3 format: $extracted_name"
    fi
    
    # Create uppercase filename with .BAS extension
    filename="${extracted_name^^}"
    tokenized_file="$TEMP_DIR/$filename"
    
    echo "  Tokenizing: $(basename "$bas_file") -> $filename"
    
    # Tokenize the file
    if ! dfstool tokenize "$bas_file" "$tokenized_file"; then
        echo "Error: Failed to tokenize $bas_file"
        exit 1
    fi
    
    TOKENIZED_FILES+=("$tokenized_file")
    TOKENIZED_NAMES+=("$filename")
done

# Create JSON manifest
JSON_FILE="$TEMP_DIR/manifest.json"
echo ""
echo "Creating JSON manifest: $JSON_FILE"

# Start JSON file
cat > "$JSON_FILE" << EOF
{
  "version": 1,
  "discTitle": "BASIC",
  "discSize": 800,
  "bootOption": "none",
  "cycleNumber": 0,
  "files": [
EOF

# Add each tokenized file to JSON
for i in "${!TOKENIZED_FILES[@]}"; do
    tokenized_file="${TOKENIZED_FILES[$i]}"
    filename="${TOKENIZED_NAMES[$i]}"
    
    # Add comma if not the last file
    if [ $i -lt $((${#TOKENIZED_FILES[@]} - 1)) ]; then
        comma=","
    else
        comma=""
    fi
    
    cat >> "$JSON_FILE" << EOF
    {
      "fileName": "$filename",
      "directory": "$",
      "locked": false,
      "loadAddress": "&1900",
      "executionAddress": "&8023",
      "contentPath": "$tokenized_file",
      "type": "basic"
    }$comma
EOF
done

# Close JSON file
cat >> "$JSON_FILE" << EOF
  ]
}
EOF

# cat $JSON_FILE
echo "JSON manifest created with ${#TOKENIZED_FILES[@]} files"

# Create SSD disk image
echo ""
echo "Creating SSD disk image: $OUTPUT_SSD"

if ! dfstool make --output "$OUTPUT_SSD" --overwrite "$JSON_FILE"; then
    echo "Error: Failed to create SSD disk image"
    exit 1
fi

echo ""
echo "Success! SSD disk image created: $OUTPUT_SSD"
echo "Files included:"
for filename in "${TOKENIZED_NAMES[@]}"; do
    echo "  - $filename"
done

echo ""
echo "You can now load this disk image in your BBC Micro emulator."
