import socket

def scan_ports():
    print("Scanning localhost ports from 1000 to 9000...")
    for port in range(1000, 9000):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.01)
        result = s.connect_ex(('127.0.0.1', port))
        if result == 0:
            print(f"Port {port} is OPEN")
        s.close()

if __name__ == "__main__":
    scan_ports()
