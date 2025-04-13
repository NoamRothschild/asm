# Utility to expose a local service to the internet on windows
from sys import platform
import subprocess, re

COLOR_RED = "\033[91m"
COLOR_GREEN = "\033[92m"
COLOR_CYAN = "\033[96m"
COLOR_GREY = "\033[90m"
COLOR_YELLOW = "\033[93m"
COLOR_RESET = "\033[0m"
ITALIC = "\033[3m"

def colored(input: str, color: str):
    print(f"{color}{input}{COLOR_RESET}", end="")

def err(input: str):
    print(f"{COLOR_RED}{input}{COLOR_RESET}")
    exit(1)

class return_object:
    def __init__(self, success: bool, message: str):
        self.success = success
        self.message = message
    
    def exit_on_err(self):
        if self.success:
            return self
        err(self.message)
    
    def get_message(self):
        return self.message
    
    def print_message(self, color: str = COLOR_RESET):
        print(f"{color}{self.message}{COLOR_RESET}")
        return self

def is_admin() -> return_object:
    out = subprocess.Popen(["powershell", "-Command", "(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = out.communicate()

    if stderr:
        return return_object(False, f"This script must be run from powershell: {stderr.decode('utf-8')}")

    if "True" not in stdout.decode("utf-8").split('\r\n'):
        return return_object(False, "This script must be run from an administrator powershell")

    return return_object(True, "")

def expose(powershell_command: str) -> return_object:
    out = subprocess.Popen(["powershell", "-Command", powershell_command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = out.communicate()

    if stderr:
        return return_object(False, f"Error exposing port: {stderr.decode('utf-8')}")

    return return_object(True, f"Port exposed successfully")

def create_firewall_rule(port: str, display_name: str = "Python ASM Exposer") -> return_object:
    out = subprocess.Popen(["powershell", "-Command", f"New-NetFirewallRule -DisplayName \"{display_name}\" -Direction Inbound -LocalPort {port} -Protocol TCP"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = out.communicate()

    if stderr:
        return return_object(False, f"Error creating firewall rule: {stderr.decode('utf-8')}")

    return return_object(True, f"Firewall rule created successfully")

def get_wsl_ip() -> return_object:
    out = subprocess.Popen(["wsl", "--exec", "ip", "addr"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = out.communicate()

    if stderr:
        return return_object(False, f"Error getting wsl ip: {stderr.decode('utf-8')}")

    wsl_ip = re.findall(r"172\.[0-9]+\.[0-9]+\.[0-9]+", stdout.decode("utf-8"))
    if len(wsl_ip) == 0:
        return return_object(False, "No wsl ip found.")

    return return_object(True, wsl_ip[0])

def confirm_input(input_msg: str) -> bool:
    colored(f"{input_msg} ", COLOR_YELLOW)
    _input = input().lower()
    return len(_input) > 0 and _input[0] == "y"

def main():

    if platform != "win32":
        err("This script is only supported on Windows and must be run from an administrator powershell")

    is_admin().exit_on_err()

    colored("Windows WSL Exposer Script\n\n", COLOR_GREEN + ITALIC)

    wsl_ip = get_wsl_ip().exit_on_err().get_message()
    print(f"{COLOR_GREEN}WSL IP: {wsl_ip}{COLOR_RESET}")

    port = input(f"{COLOR_CYAN}Please enter a port to expose: {COLOR_RESET}")
    if not port.isdigit():
        err("Port must be a number")

    powershell_command = f"netsh interface portproxy add v4tov4 listenport={port} listenaddress=0.0.0.0 connectport={port} connectaddress={wsl_ip}"

    if confirm_input("Confirm running command netsh? [Y/n]"):
        expose(powershell_command).exit_on_err().print_message(color=COLOR_GREEN)
    else:
        print(f"\n{COLOR_GREY}Please run the following command from an {COLOR_GREEN}ADMINISTRATOR POWERSHELL{COLOR_GREY} to expose the port:{COLOR_RESET}")
        print(f"\n```powershell\n{COLOR_CYAN}{powershell_command}{COLOR_RESET}\n```")
        input("Press Enter to continue...")
    
    if confirm_input("Create firewall rule? [Y/n]"):
        rule_name = input(f"{COLOR_CYAN}Please enter a name for the firewall rule {COLOR_GREY}(default: Python ASM Exposer){COLOR_CYAN}: {COLOR_RESET}").strip()
        create_firewall_rule(port, rule_name if len(rule_name) > 0 else "Python ASM Exposer").exit_on_err().print_message(color=COLOR_GREEN)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        err("\nAborted by user.")