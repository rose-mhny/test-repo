#!/bin/bash

JSON_FILE="shifts.json"
touch "$JSON_FILE"
if [ ! -s "$JSON_FILE" ]; then
    echo "{}" > "$JSON_FILE"
fi

# Valid shifts and teams
valid_shifts=("morning" "mid" "night")
valid_teams=("a1" "a2" "a3" "b1" "b2" "b3")

# Function to center text
center() {
    local s="$1"
    local w="$2"
    local len=${#s}
    local spaces=$(( w - len ))
    local left=$(( spaces / 2 ))
    local right=$(( spaces - left ))

    pad_left=""
    for ((i=0; i<left; i++)); do pad_left="$pad_left "; done
    pad_right=""
    for ((i=0; i<right; i++)); do pad_right="$pad_right "; done

    echo -n "$pad_left$s$pad_right"
}

print_schedule() {
    local width_team=8
    local width_shift=10
    local width_emp=12  # minimum

    # Find max employee list length
    max_emp=0
    for team in "${valid_teams[@]}"; do
        for shift in "${valid_shifts[@]}"; do
            employees=$(jq -r --arg t "$team" --arg s "$shift" '
                if .[$t][$s] and (.[$t][$s] | length) > 0 then
                    .[$t][$s] | join(", ")
                else
                    empty
                end
            ' "$JSON_FILE")
            length=${#employees}
            if [ $length -gt $max_emp ]; then
                max_emp=$length
            fi
        done
    done

    # Adjust column width if needed
    if [ $max_emp -gt $width_emp ]; then
        width_emp=$((max_emp + 2))
    fi

    # Top border
    printf "╔%s╦%s╦%s╗\n" \
        "$(printf '═%.0s' $(seq 1 $width_team))" \
        "$(printf '═%.0s' $(seq 1 $width_shift))" \
        "$(printf '═%.0s' $(seq 1 $width_emp))"

    # Header row
    printf "║\033[1m%s\033[0m║\033[1m%s\033[0m║\033[1m%s\033[0m║\n" \
        "$(center "Team" $width_team)" \
        "$(center "Shift" $width_shift)" \
        "$(center "Employees" $width_emp)"

    # Divider
    printf "╠%s╬%s╬%s╣\n" \
        "$(printf '═%.0s' $(seq 1 $width_team))" \
        "$(printf '═%.0s' $(seq 1 $width_shift))" \
        "$(printf '═%.0s' $(seq 1 $width_emp))"

    # Rows
    rows=()
    for team in "${valid_teams[@]}"; do
        for shift in "${valid_shifts[@]}"; do
            employees=$(jq -r --arg t "$team" --arg s "$shift" '
                if .[$t][$s] and (.[$t][$s] | length) > 0 then
                    .[$t][$s] | join(", ")
                else
                    empty
                end
            ' "$JSON_FILE")
            if [[ -n "$employees" ]]; then
                rows+=("║$(center "$team" $width_team)║$(center "$shift" $width_shift)║$(center "$employees" $width_emp)║")
            fi
        done
    done

    # Print rows with dividers
    for i in "${!rows[@]}"; do
        echo -e "${rows[$i]}"
        if [[ $i -lt $((${#rows[@]} - 1)) ]]; then
            printf "╠%s╬%s╬%s╣\n" \
                "$(printf '─%.0s' $(seq 1 $width_team))" \
                "$(printf '─%.0s' $(seq 1 $width_shift))" \
                "$(printf '─%.0s' $(seq 1 $width_emp))"
        fi
    done

    # Bottom border
    printf "╚%s╩%s╩%s╝\n" \
        "$(printf '═%.0s' $(seq 1 $width_team))" \
        "$(printf '═%.0s' $(seq 1 $width_shift))" \
        "$(printf '═%.0s' $(seq 1 $width_emp))"

    echo -e "\nPress Enter to continue..."
    read
    echo -e ""
}

while true; do
    read -p "Enter Employee name (or 'print' to display schedule, 'remove' to delete, 'exit' to quit): " name
    name=$(echo "$name" | sed 's/^ *//;s/ *$//' | tr '[:upper:]' '[:lower:]')

    if [[ "$name" == "exit" ]]; then
        break
    fi

    if [[ "$name" == "print" ]]; then
        print_schedule
        continue
    fi

    if [[ "$name" == "remove" ]]; then
        read -p "Enter Team to remove from (a1/a2/a3/b1/b2/b3): " team
        team=$(echo "$team" | tr '[:upper:]' '[:lower:]')
        [[ ! " ${valid_teams[*]} " =~ " $team " ]] && { echo -e "${RED}❌ Invalid team.${RESET}\n"; continue; }

        read -p "Enter Shift to remove from (morning/mid/night): " shift
        shift=$(echo "$shift" | tr '[:upper:]' '[:lower:]')
        [[ ! " ${valid_shifts[*]} " =~ " $shift " ]] && { echo -e "${RED}❌ Invalid shift.${RESET}\n"; continue; }

        read -p "Enter Employee name to remove: " emp
        emp=$(echo "$emp" | sed 's/^ *//;s/ *$//' | tr '[:upper:]' '[:lower:]')

        exists=$(jq --arg t "$team" --arg s "$shift" --arg n "$emp" '.[$t][$s] | index($n)' "$JSON_FILE")
        if [[ "$exists" == "null" ]]; then
            echo -e "${RED}❌ Employee $emp not found in $team $shift.${RESET}\n"
            continue
        fi

        jq --arg t "$team" --arg s "$shift" --arg n "$emp" '.[$t][$s] -= [$n]' "$JSON_FILE" > tmp.json && mv tmp.json "$JSON_FILE"
        echo -e "${GREEN}✅ Removed $emp from team $team ($shift shift).${RESET}\n"
        continue
    fi

    # Adding employee
    read -p "Enter Shift (morning/mid/night): " shift
    shift=$(echo "$shift" | tr '[:upper:]' '[:lower:]')
    [[ ! " ${valid_shifts[*]} " =~ " $shift " ]] && { echo -e "${RED}❌ Invalid shift.${RESET}\n"; continue; }

    read -p "Enter Team (a1/a2/a3/b1/b2/b3): " team
    team=$(echo "$team" | tr '[:upper:]' '[:lower:]')
    [[ ! " ${valid_teams[*]} " =~ " $team " ]] && { echo -e "${RED}❌ Invalid team.${RESET}\n"; continue; }

    # Initialize JSON
    jq --arg t "$team" --arg s "$shift" 'if .[$t]==null then .[$t]={} else . end | if .[$t][$s]==null then .[$t][$s]=[] else . end' "$JSON_FILE" > tmp.json && mv tmp.json "$JSON_FILE"

    # Shift limit
    count=$(jq --arg t "$team" --arg s "$shift" '.[$t][$s] | length' "$JSON_FILE")
    (( count >= 2 )) && { echo -e "${RED}❌ Error: Maximum employees per shift in team $team reached.${RESET}\n"; continue; }

    # Duplicate check
    exists=$(jq --arg t "$team" --arg s "$shift" --arg n "$name" '.[$t][$s] | index($n)' "$JSON_FILE")
    [[ "$exists" != "null" ]] && { echo -e "${RED}❌ Error: $name already assigned to $team $shift.${RESET}\n"; continue; }

    # Add employee
    jq --arg t "$team" --arg s "$shift" --arg n "$name" '.[$t][$s] += [$n]' "$JSON_FILE" > tmp.json && mv tmp.json "$JSON_FILE"
    echo -e "${GREEN}✅ Assigned $name to team $team ($shift shift).${RESET}\n"
done
