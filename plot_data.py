from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import scienceplots
from matplotlib.colors import to_hex

SAVE = True
LEGEND = True

SCATTER_STYLE = dict(edgecolor="white", linewidth=0.2)
LEGEND_STYLE = dict(frameon=True, fancybox=False, framealpha=0.6)


def plot_data() -> None:
    root_basename = "generated_workflows"
    save_basename = "plots_legend" if LEGEND else "plots"

    if input("Nonlinear? (y/n) ") == "y":
        root_basename = "nonlinear_" + root_basename
        save_basename = "nonlinear_" + save_basename

    root_path: Path = Path(__file__).parents[0] / root_basename
    save_path: Path = Path(__file__).parents[0] / save_basename

    markers = ["o", "X", "s", "^", "D", "v", "<", ">", "P", "p", "*", "h", "H", "+", "x", "D", "d"]
    new_palette = sns.color_palette() + sns.color_palette("muted") + sns.color_palette("deep")
    sns.set_palette(new_palette)
    colors = list(sns.color_palette(n_colors=16))

    for dir in root_path.iterdir():
        if not dir.is_dir():
            continue
        for file in dir.rglob("data.csv"):
            print(file)
            workflow = file.parents[0].name

            df: pd.DataFrame = pd.read_csv(file)
            fig, ax = plt.subplots(figsize=(4, 3))

            y = "CPU Work per Core"
            # y = "CPU Work"

            for abstract_task, color, marker in zip(df["Abstract Task"].unique(), colors, markers):
                sub_df = df[df["Abstract Task"] == abstract_task]
                ax.scatter(sub_df["Input Data in Bytes"], sub_df[y], color=color, marker=marker,
                           label=abstract_task, **SCATTER_STYLE)
                print(abstract_task, to_hex(color), marker)

            # plt.title(f"{workflow} - CPU Work per Core vs Input Data")
            ax.set_xlabel("Input Data in Bytes")
            ax.set_ylabel("CPU Work per Core")
            ax.set_xscale("log")
            ax.set_yscale("log")
            if LEGEND:
                plt.legend(**LEGEND_STYLE, loc=(1.02, 0))

            print(f"Currently at Input-Work Relationship plot ({workflow})")
            if SAVE:
                yes = input("Save this? (y/n) ") == "y"
                if yes:
                    fig.savefig(save_path / f"{workflow}.pdf", bbox_inches='tight')
            if not SAVE:
                plt.show()

    print(root_path)


def main() -> None:
    global SAVE
    global LEGEND
    SAVE = input("Save plots? (y/n) ") == "y"
    LEGEND = input("Show legend? (y/n) ") == "y"
    plt.style.use("science")
    plt.rcParams["font.size"] = 12

    plot_data()


if __name__ == "__main__":
    main()
