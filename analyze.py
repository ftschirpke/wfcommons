from pathlib import Path


def analyze_file_sizes() -> None:
    root_path: Path = Path(__file__).parents[0] / "generated_workflows"

    c = {}

    for dir in root_path.iterdir():
        if not dir.is_dir():
            continue
        for file in dir.rglob("to_create.txt"):
            workflow = file.parents[0].name
            with open(file, "r") as f:
                lines = f.readlines()

            counts = [int(line.split()[1]) for line in lines]
            c[workflow.replace("_", " ")] = counts

    for workflow in sorted(c.keys()):
        print(f"{workflow:30} => {sum(c[workflow]) / 1024 ** 3:10_.2f} GB")


def main() -> None:
    analyze_file_sizes()


if __name__ == "__main__":
    main()
