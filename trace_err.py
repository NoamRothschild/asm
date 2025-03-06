"""
Catches any system crashes and displays them using `dmesg`.
Usefull for example when a seperate thread crashed and you were not able to catch its error

`dmesg` shows the registers (including instruction pointer) at crash time, executable & thread.
to understand at which line the code crashed, use the following commands

```
gdb ./COMPILED_FILE

layout asm
disassemble 0xEIP
```

example:

we see our code crashed, but we don't know why. we run this script in parallel, 
& try to reproduce the crash. once succeded we will see a large dump of the system, 
along its lines we will have something similar to this:

logs show this line `main[81436] trap divide error ip:80494e2 sp:ffd4f10c` along with more of the data.
                                                   ^ EIP

so we run while inside gdb (after running `layout asm`) the line 
`disassemble 0x80494e2`

hope that helps ;)
"""
import subprocess
import difflib
import time
import os

# Execute a shell command and return its output with color codes preserved.
def execute(cmd: str) -> None:
    try:
        # Force color output in common commands by adding environment variables
        env = os.environ.copy()
        env['FORCE_COLOR'] = '1'
        env['CLICOLOR_FORCE'] = '1'
        
        # Use shell=True to interpret pipes and redirects
        result = subprocess.check_output(
            cmd, 
            shell=True, 
            env=env,
            universal_newlines=True,
            stderr=subprocess.STDOUT
        )
        return result.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        return ''

# Generate a unified diff between two texts.
def diff(old_text: str, new_text: str) -> str:

    # Generate diff
    diff_lines = list(difflib.unified_diff(
        old_text.splitlines(),
        new_text.splitlines(),
        fromfile='Previous',
        tofile='Current',
        lineterm=''
    ))
   
    # Return diff as a single string
    return '\n'.join(diff_lines)

def monitor_system_logs(cmd: str = 'dmesg --color=always | tail -n 20', interval: int = 5):
    # Monitors system logs and print differences.
    old_res = '' # can be set to execute(cmd) instead of nothing to not see the last crash
   
    try:
        print(f"Starting log monitoring using command: {cmd}")
        print(f"Press Ctrl+C to stop")
        
        while True:
            res = execute(cmd)
           
            if res != old_res:
                print("\nSystem log changes detected:")
                print("\nCurrent output:")
                print(res)
                print("\nChanges:")
                print(diff(old_res, res))
                old_res = res

            time.sleep(interval)
   
    except KeyboardInterrupt:
        print("\nLog monitoring stopped.")

if __name__ == '__main__':
    monitor_system_logs()