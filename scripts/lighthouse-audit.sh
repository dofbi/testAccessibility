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
timeout_duration=180

# Get current date and time
current_datetime=$(date '+%Y-%m-%d_%H-%M-%S')

# Create the report directory with the current date and time
report_directory="$reports_dir/$current_datetime"
mkdir -p "$report_directory"

# Path to the output CSV file with a fixed name within the report directory
output_csv_file="$report_directory/lighthouse_scores.csv"

# Write headers to the output CSV file
echo "url,score,Performance,Accessibility,Best Practices,SEO,nom" > "$output_csv_file"

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
        echo "$url,,,,,$name" >> "$output_csv_file"
    else
        echo "Fetched Lighthouse report for $url successfully and saved to $json_file"
        
        # Extract scores from the JSON report and remove the JSON file to save space
        if [ -f "$json_file" ]; then
            performance=$(jq '.categories.performance.score // 0' "$json_file")
            accessibility=$(jq '.categories.accessibility.score // 0' "$json_file")
            best_practices=$(jq '.categories."best-practices".score // 0' "$json_file")
            seo=$(jq '.categories.seo.score // 0' "$json_file")
            
            # Remove JSON file after extracting the necessary information
            rm "$json_file"
            
            # Convert scores from 0-1 to 0-100 scale
            performance=$(awk -v score=$performance 'BEGIN { print score * 100 }')
            accessibility=$(awk -v score=$accessibility 'BEGIN { print score * 100 }')
            best_practices=$(awk -v score=$best_practices 'BEGIN { print score * 100 }')
            seo=$(awk -v score=$seo 'BEGIN { print score * 100 }')
            
            # Calculate the average score
            score=$(awk -v p=$performance -v a=$accessibility -v b=$best_practices -v s=$seo 'BEGIN { print (p + a + b + s) / 4 }')
            
            # Write the results to the output CSV file
            echo "$url,$score,$performance,$accessibility,$best_practices,$seo,$name" >> "$output_csv_file"
        else
            echo "$url,,,,,$name" >> "$output_csv_file"
        fi
    fi
done

# Sort the results by the new score column and write to a temporary CSV file
sorted_csv_file="$report_directory/sorted_lighthouse_scores.csv"
{
    head -n 1 "$output_csv_file"
    tail -n +2 "$output_csv_file" | sort -t, -k2,2nr
} > "$sorted_csv_file"

# Overwrite the original output CSV file with the sorted results
mv "$sorted_csv_file" "$output_csv_file"
