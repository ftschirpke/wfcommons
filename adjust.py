import sys

if len(sys.argv) > 1:
    filename = sys.argv[1]
else:
    raise SystemExit("Usage: python adjust.py filename")

output = []

with open(filename) as file:
    lines = file.readlines()
    for i, line in enumerate(lines):
        if "process" in line:
            output.append(f"withName: '{line.split()[1]}' {{")
            next_line = lines[i + 1]
            if "cpus" in next_line:
                output.append(f"    cpus = {next_line.split()[1]}")
                next_line = lines[i + 2]
            else:
                output.append("    cpus = 1")
            if "memory" in next_line:
                split = next_line.split()
                value = float(split[1][1:])
                value = round(value * 1.2, 2)
                unit = split[2][:-1]
                if unit in ["KB", "MB"]:
                    print(f"Error: found {value} {unit} in {filename}")
                    exit(1)
                output.append(f"    memory = '{value}{unit}'")
            else:
                print(f"Error: found no memory value in {filename}")
                exit(1)
            output.append("}")


print("process {", end="\n    ")
print("\n    ".join(output))
print("}")
