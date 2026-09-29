
# Launch fish shell automatically unless bash was started from fish
if command -v fish &> /dev/null && [[ $- == *i* ]]; then
    parent_process=$(ps -o comm= -p $(ps -o ppid= -p $$))
    if [[ "$parent_process" != "fish" ]]; then
        exec fish
    fi
fi
