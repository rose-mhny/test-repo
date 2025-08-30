#!/bin/bash

SCHEDULE_FILE="schedule.txt"
touch "$SCHEDULE_FILE"

while true; do
    read -p "Enter Employee name ('exit' to quit): " name
    if [[ "$name" == "exit" ]]; then
        break
    fi

    read -p "Enter Shift (morning/mid/night): " shift
    shift=$(echo "$shift" | tr '[:upper:]' '[:lower:]')
    if [[ ! "$shift" =~ ^(morning|mid|night)$ ]]; then
        echo -e "❌ Invalid shift. Must be: morning, mid, or night.\n"
        break
    fi

    read -p "Enter Team (a1/a2/a3/b1/b2/b3): " team
    team=$(echo "$team" | tr '[:upper:]' '[:lower:]')
    if [[ ! "$team" =~ ^(a1|a2|a3|b1|b2|b3)$ ]]; then
        echo -e "❌ Invalid team. Must be one of: a1, a2, a3, b1, b2, b3.\n"
        break
    fi

    echo "$team,$shift,$name" >> "$SCHEDULE_FILE"
    echo -e "✅ Assigned $name to team $team ($shift shift).\n"
done


