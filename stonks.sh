#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Usage: stonks.sh -option \"...\" "
    echo "Options: "
    echo "  -f, use f to provide a CSV file of historical stock data in the second argument."
    echo "  -s, use s to provide a single stock symbol in the second argument."
    exit 22
fi 

#if s is used, ask the period and fetch the data
if [[ $1 = "-s" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Argument missing for -s option."
        exit 22
    fi
    echo "Enter the time period in days(mm/dd/yyyy): "
    echo "from: "
    read from
    echo "to: "
    read to
    curl -s "https://query1.finance.yahoo.com/v7/finance/download/$2?period1=$(date -d "$from 00:00:00" +"%s")&period2=$(date -d "$to 23:59:59" +"%s")&interval=1d&events=history" > "$2.csv"
    in="$2.csv"
else
    in="$2"
fi

# Find indices of the headers in the given .CSV 
headers=("Date" "Open" "High" "Low" "Close" "Volume")
heading=( $(head -n 1 "$in" | tr "," " ") )
declare -A ind
for i in "${!headers[@]}"; do
    for j in "${!heading[@]}"; do 
        if [[ "${headers[$i]}" = "${heading[$j]}" ]]; then
            ind[${headers[$i]}]="$j"
        fi
    done
done

# Spit out monthly stock prices data
mn=monthly-output.csv
echo "Month,Open,High,Low,Close,Volume" > "$mn"
prev=""
open="$(awk -F, -v c_2="${ind['High']}" '{print $c_2}' <<< "$(head -n 2 "$in" | tail -1)")"
close=""
declare -a high
declare -a low
volume=0

# Process the data line by line, assuming specific column positions
tail -n +2 "$in" | while IFS=, read -r date open high low close _skip volume_raw; do
    volume=$(echo "$volume + $volume_raw" | bc)
    current_month="${date%%-*}"

    if [[ "$current_month" != "$prev" ]]; then
        # Output the previous month's data
        if [[ -n "$prev" ]]; then
            echo "$prev, $open, $(printf "%s\n" "${high[@]}" | sort -nr | head -n1), $(printf "%s\n" "${low[@]}" | sort -nr | tail -n1), $close, $volume" >> "$mn"
        fi

        # Reset variables for the new month
        prev="$current_month"
        open="$open"
        high=("$high")
        low=("$low")
        volume_raw=0
        close="$close"
    else
        # Update high, low, and close for the same month
        high+=("$high")
        low+=("$low")
        close="$close"
    fi
done

# Output the last month's data
if [[ -n "$prev" ]]; then
    echo "$prev, $open, $(printf "%s\n" "${high[@]}" | sort -nr | head -n1), $(printf "%s\n" "${low[@]}" | sort -nr | tail -n1), $close, $volume" >> "$mn"
fi
