#!/bin/bash

# Verify log file exists
if [ $# -ne 1 ]; then
    echo "❗ Please specify log file: $0 <log_file>"
    exit 1
fi

logfile=$1

if [ ! -f "$logfile" ]; then
    echo "❌ Log file not found!"
    exit 1
fi

# Create report file
report_file="web_log_report_$(date +%Y%m%d_%H%M%S).md"

# Header printing function
print_header() {
    echo -e "\n## $1" >> $report_file
    echo -e "---" >> $report_file
}

# Start report
echo -e "# 📊 Web Server Log Analysis Report\n" > $report_file
echo -e "**Log File:** $logfile" >> $report_file
echo -e "**Report Date:** $(date)\n" >> $report_file

# 1. Request Counts
print_header "1. Request Statistics"
total=$(wc -l < "$logfile")
get=$(grep -c 'GET ' "$logfile")
post=$(grep -c 'POST ' "$logfile")
other=$((total - get - post))

echo -e "- Total Requests: **$total**" >> $report_file
echo -e "- GET Requests: **$get**" >> $report_file
echo -e "- POST Requests: **$post**" >> $report_file
[ $other -gt 0 ] && echo -e "- Other Methods: **$other**" >> $report_file

# 2. Unique IP Analysis
print_header "2. IP Address Analysis"
unique_ips=$(awk '{print $1}' "$logfile" | sort | uniq | wc -l)
echo -e "- Unique IP Count: **$unique_ips**" >> $report_file

echo -e "\n### GET/POST Counts per IP (Top 10)" >> $report_file
echo -e "\`\`\`" >> $report_file
awk '{ip=$1; method=$6; counts[ip][method]++} END {for (ip in counts) {printf "%s: GET=%d POST=%d\n", ip, counts[ip]["\"GET"], counts[ip]["\"POST"]}}' "$logfile" | sort -k3 -nr | head -10 >> $report_file
echo -e "\`\`\`" >> $report_file

# 3. Failure Analysis
print_header "3. Failure Analysis"
failed=$(awk '$9 ~ /^[45][0-9][0-9]$/ {count++} END {print count}' "$logfile")
percent=$(awk "BEGIN {printf \"%.2f\", $failed/$total*100}")

echo -e "- Failed Requests (4xx/5xx): **$failed**" >> $report_file
echo -e "- Failure Percentage: **$percent%**" >> $report_file

# 4. Top Users
print_header "4. Top Users"
echo -e "### Most Active IP (All Requests)" >> $report_file
echo -e "\`\`\`" >> $report_file
awk '{print $1}' "$logfile" | sort | uniq -c | sort -nr | head -1 >> $report_file
echo -e "\`\`\`" >> $report_file

# 5. Daily Analysis
print_header "5. Daily Patterns"
echo -e "### Requests per Day" >> $report_file
echo -e "\`\`\`" >> $report_file
awk -F'[:[]' '{print $2}' "$logfile" | awk '{print $1}' | sort | uniq -c >> $report_file
echo -e "\`\`\`" >> $report_file

days=$(awk -F'[:[]' '{print $2}' "$logfile" | awk '{print $1}' | sort | uniq | wc -l)
avg=$(awk "BEGIN {printf \"%.2f\", $total/$days}")
echo -e "- Average Requests/Day: **$avg**" >> $report_file

# 6. Failure Patterns
print_header "6. Failure Patterns"
echo -e "### Days With Most Failures" >> $report_file
echo -e "\`\`\`" >> $report_file
awk '$9 ~ /^[45][0-9][0-9]$/ {print $4}' "$logfile" | awk -F'[:[]' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 >> $report_file
echo -e "\`\`\`" >> $report_file

# Additional: Hourly Trends
print_header "⏰ Hourly Request Trends"
echo -e "\`\`\`" >> $report_file
awk -F'[:[]' '{print $2}' "$logfile" | awk '{print $2}' | awk -F: '{print $1}' | sort | uniq -c >> $report_file
echo -e "\`\`\`" >> $report_file

# Additional: Status Codes
print_header "🔢 Status Code Distribution"
echo -e "\`\`\`" >> $report_file
awk '{print $9}' "$logfile" | sort | uniq -c | sort -nr >> $report_file
echo -e "\`\`\`" >> $report_file

# Additional: Method-Specific Users
print_header "👥 Method-Specific Top Users"
echo -e "### Top GET Requesters" >> $report_file
echo -e "\`\`\`" >> $report_file
grep 'GET ' "$logfile" | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 >> $report_file
echo -e "\`\`\`" >> $report_file

echo -e "### Top POST Requesters" >> $report_file
echo -e "\`\`\`" >> $report_file
grep 'POST ' "$logfile" | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 >> $report_file
echo -e "\`\`\`" >> $report_file

# Failure Hours Analysis
print_header "🕒 Failure Time Patterns"
echo -e "### Hours With Most Failures" >> $report_file
echo -e "\`\`\`" >> $report_file
awk '$9 ~ /^[45][0-9][0-9]$/ {print $4}' "$logfile" | awk -F: '{print $2}' | sort | uniq -c | sort -nr | head -5 >> $report_file
echo -e "\`\`\`" >> $report_file

# Recommendations
print_header "💡 Actionable Recommendations"
echo -e "1. **Error Reduction**:" >> $report_file
awk '$9 ~ /^404/ {print $7}' "$logfile" | sort | uniq -c | sort -nr | head -3 | awk '{print "   - Fix missing resource: " $2 " (occurred " $1 " times)"}' >> $report_file

echo -e "\n2. **Performance Optimization**:" >> $report_file
awk -F'[:[]' '{print $2}' "$logfile" | awk '{print $2}' | awk -F: '{print $1}' | sort | uniq -c | sort -nr | head -1 | awk '{print "   - Scale resources during hour " $2 " (peak: " $1 " requests)"}' >> $report_file

echo -e "\n3. **Security Monitoring**:" >> $report_file
grep 'POST ' "$logfile" | awk '{print $1}' | sort | uniq -c | sort -nr | head -1 | awk '{print "   - Monitor IP " $2 " (suspicious: " $1 " POST requests)"}' >> $report_file

echo -e "\n4. **Caching Opportunities**:" >> $report_file
grep 'GET ' "$logfile" | awk '{print $7}' | sort | uniq -c | sort -nr | head -3 | awk '{print "   - Cache resource: " $2 " (requested " $1 " times)"}' >> $report_file

echo -e "\n\n✅ Report generated successfully: $report_file"