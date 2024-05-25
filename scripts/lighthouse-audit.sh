#!/bin/bash

# Default paths (can be overridden by command line arguments)
resources_dir="resources"
reports_dir="Rapports"

# Parse command line arguments for custom paths
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --resources) resources_dir="$2"; shift ;;
        --reports) reports_dir="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Path to the input CSV file
input_csv_file="$resources_dir/annuaire.csv"

# Timeout duration in seconds
timeout_duration=60

# Get current date and time
current_datetime=$(date '+%Y-%m-%d_%H-%M-%S')

# Create the report directory with the current date and time
report_directory="$reports_dir/$current_datetime"
mkdir -p "$report_directory"

# Path to the output CSV file with a fixed name within the report directory
output_csv_file="$report_directory/lighthouse_scores.csv"

# Temporary file to store results before sorting
temp_csv_file="$report_directory/temp_lighthouse_scores.csv"

# Write headers to the temporary CSV file
echo "url,Performance,Accessibility,Best Practices,SEO,nom" > "$temp_csv_file"

# Read the URLs from the CSV file and run Lighthouse for each URL
awk -F ',' 'NR > 1 {print $1 "," $2 "," $3}' "$input_csv_file" | while IFS=, read -r name url type; do
    # Remove leading and trailing whitespace from URL
    url=$(echo "$url" | xargs)
    
    # Remove http:// and https:// from the URL
    cleaned_url=$(echo "$url" | sed 's|http[s]*://||g')
    
    # Generate a valid filename from the cleaned URL
    json_file="$report_directory/${cleaned_url//[^a-zA-Z0-9]/_}.json"
    
    echo "Fetching Lighthouse report for $url with a timeout of $timeout_duration seconds..."
    
    # Use npx to run the local version of Lighthouse and generate JSON report
    timeout $timeout_duration npx lighthouse "$url" --output json --output-path "$json_file" --chrome-flags="--headless"
    
    if [ $? -eq 124 ]; then
        echo "Timeout occurred for $url"
        echo "$url,,,,$name" >> "$temp_csv_file"
    else
        echo "Fetched Lighthouse report for $url successfully and saved to $json_file"
        
        # Extract scores from the JSON report
        performance=$(jq '.categories.performance.score // 0' "$json_file")
        accessibility=$(jq '.categories.accessibility.score // 0' "$json_file")
        best_practices=$(jq '.categories."best-practices".score // 0' "$json_file")
        seo=$(jq '.categories.seo.score // 0' "$json_file")
        
        # Convert scores from 0-1 to 0-100 scale
        performance=$(awk -v score=$performance 'BEGIN { print score * 100 }')
        accessibility=$(awk -v score=$accessibility 'BEGIN { print score * 100 }')
        best_practices=$(awk -v score=$best_practices 'BEGIN { print score * 100 }')
        seo=$(awk -v score=$seo 'BEGIN { print score * 100 }')
        
        # Write the results to the temporary CSV file
        echo "$url,$performance,$accessibility,$best_practices,$seo,$name" >> "$temp_csv_file"
    fi
done

# Sort the results by Performance, Accessibility, Best Practices, and SEO and write to the final output CSV file
# Skip the header line while sorting and then re-add it at the top of the final output
{
    head -n 1 "$temp_csv_file"
    tail -n +2 "$temp_csv_file" | sort -t, -k2,2nr -k3,3nr -k4,4nr -k5,5nr
} > "$output_csv_file"

# Remove the temporary CSV file
rm "$temp_csv_file"
