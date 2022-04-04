from montage_recipes.montage_test import Montage_testRecipe
from wfcommons.wfgen import WorkflowGenerator
import pathlib 

this_dir = pathlib.Path(__file__).parent.resolve()
recipe = Montage_testRecipe
num_tasks = [7119, 9807]
save_dir = this_dir.joinpath("MontageTest")


for num in num_tasks:
    generator = WorkflowGenerator(recipe.from_num_tasks(num))
    workflow = generator.build_workflow()
    workflow.name = f"{workflow.name.split('-')[0]}"
    json_path = save_dir.joinpath(
        f"{workflow.name.lower()}-{num}").with_suffix(".json")
