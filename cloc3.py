import re, os
from sys import argv
pattern = r"%include\s+'([^']+)"

if len(argv) < 2:
    print("Example usage:")
    print(f"python3 {os.path.basename(__file__)} path/to/file")
    print("Requires the cloc command to be installed.")
    exit()

def get_files_list(filename: str, files_list: list):
    file = open(filename, 'r').read()
    files_list.append(filename)
    included_files = re.findall(pattern, file)
    for new_file in included_files:
        files_list += get_files_list(new_file, [])
    return files_list

os.chdir(os.path.abspath(os.path.dirname(argv[1])))

os.system("cloc " + ' '.join(get_files_list(os.path.basename(argv[1]), [])))