from wfcommons.wfchef.utils import remove_base_graphs
import pathlib
import pandas as pd

thisdir = pathlib.Path(__file__).resolve().parent

def main():
    df = pd.read_csv(thisdir.joinpath("err.csv"),index_col=0)

    print(df)
    df = remove_base_graphs(df, graph_to_remove=[
        "montage-chameleon-2mass-005d-001",
        "montage-chameleon-dss-05d-001"
    ]) 

    print(df)

if __name__ == "__main__":
    main()