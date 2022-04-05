from scratch.montage.montage_recipes import Montage_testRecipe
from wfcommons.wfgen import WorkflowGenerator
import pathlib 

this_dir = pathlib.Path(__file__).parent.resolve()
recipe = Montage_testRecipe
num_tasks = [7119, 9807]
save_dir = this_dir.joinpath("MontageTest")
save_dir.mkdir(exist_ok=True, parents=True)

for num in num_tasks:
    generator = WorkflowGenerator(recipe.from_num_tasks(num))
    workflow = generator.build_workflow()
    workflow.name = f"{workflow.name.split('-')[0]}"
    json_path = save_dir.joinpath(f"{workflow.name.lower()}-{num}").with_suffix(".json")
    
    json_path.parent.mkdir(exist_ok=True, parents=True)
    workflow.write_json(json_path)
