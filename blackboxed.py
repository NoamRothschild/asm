import os
os.chdir(os.path.abspath(os.path.dirname(__file__)))
try:
    from termcolor import colored
except ImportError:
    colored = lambda msg, _: msg

def foo(dir):
    warn_count = 0
    for file in os.listdir(path=dir):
        if file == 'misc': continue
        path = os.path.join(dir, file)
        if os.path.isdir(file):
            warn_count += foo(path)
        elif str(file).endswith('.asm'):
            warn_count += test_file(path)
    return warn_count

def test_file(fpath):
    register_list: list[str] = ['eax', 'ebx', 'ecx', 'edx', 'edi', 'esi', 'al', 'ah', 'bl', 'bh', 'cl', 'ch', 'dl', 'dh', 'ax', 'bx', 'cx', 'dx']
    is_label = lambda line: ':' in line.split(';')[0] and '.' not in line.split(';')[0]
    fetch_registers = lambda line: [reg for reg in line.split(' ') if reg in register_list]

    warn_count = 0

    with open(fpath, 'r') as f:
        found_registers: set[str] = set()
        blackboxed_registers: set[str] = set()
        function_name: str | None = None
        blackboxing_phase = False

        for line in f.readlines():
            if '_start' in line: continue
            if is_label(line):
                if (diff := blackboxed_registers ^ found_registers):
                    diff -= {reg for reg in diff if len(reg) == 2 and f'e{reg[0]}x' in blackboxed_registers}
                    if diff:
                        warn_message = f"Warning in file {fpath}, function {function_name.strip().split(':')[0]}\nFollowing registers are not blackboxed: {diff}\n"
                        print(colored(warn_message, "yellow"))
                        warn_count += 1

                blackboxing_phase = True
                found_registers = set()
                blackboxed_registers = set()
                function_name = line
            else:
                stripped = line.strip().split(';')[0]
                if stripped == '': continue
                if not function_name: continue
                if all(reg in stripped for reg in ('ebp', 'esp', 'mov')): continue

                if 'push' not in stripped:
                    blackboxing_phase = False
                elif blackboxing_phase and 'push' in stripped:
                    register = next((word for word in stripped.split('push ')[1].split(' ') if word), None)
                    if register in register_list:
                        blackboxed_registers.add(register)
                    continue
                for register in fetch_registers(stripped):
                    found_registers.add(register)

        if (diff := blackboxed_registers ^ found_registers):
            diff -= {reg for reg in diff if len(reg) == 2 and f'e{reg[0]}x' in blackboxed_registers}
            if diff:
                warn_message = f"Warning in file {fpath}, function {function_name.strip().split(':')[0]}\nFollowing registers are not blackboxed: {diff}\n"
                print(colored(warn_message, "yellow"))
                warn_count += 1
    return warn_count

if __name__ == "__main__":
    if (warn_count := foo('.')) == 0:
        print(colored("No warnings issued.", "green"))
    else:
        print(colored(f"{warn_count} warnings found.", "red"))
