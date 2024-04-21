
import groovy.json.JsonSlurper
def jsonSlurper = new JsonSlurper()

List<String> extractTaskIDforFile(Path filepath, String task_name) {
  String filename = filepath as String
  filename = filename[filename.lastIndexOf('/')+1..-1]

  List<String> ids_for_file = new ArrayList<String>()
  for (destination : file_inputs[filename]) {
    def destination_task_name = destination[0]
    def destination_task_id = destination[1]
    if (destination_task_name == task_name)
      ids_for_file.add(destination_task_id)
  }
  return ids_for_file
}

// define amount of input files for abstracts tasks where the amount is not constant
def cycles_output_summary_input_amounts = [
  "00000065": 57,
  "00000131": 51,
  "00000197": 51,
  "00000263": 48,
  "00000329": 48,
  "00000395": 51,
  "00000461": 51,
  "00000527": 51,
  "00000593": 48,
  "00000659": 51,
]
def cycles_fertilizer_increase_output_summary_input_amounts = [
  "00000066": 19,
  "00000132": 17,
  "00000198": 17,
  "00000264": 16,
  "00000330": 16,
  "00000396": 17,
  "00000462": 17,
  "00000528": 17,
  "00000594": 16,
  "00000660": 17,
]

file_inputs = jsonSlurper.parseText(file("${projectDir}/file_inputs.json").text)
baseline_cycles_args = jsonSlurper.parseText(file("${projectDir}/baseline_cycles_args.json").text)
cycles_args = jsonSlurper.parseText(file("${projectDir}/cycles_args.json").text)
fertilizer_increase_cycles_args = jsonSlurper.parseText(file("${projectDir}/fertilizer_increase_cycles_args.json").text)
cycles_fertilizer_increase_output_parser_args = jsonSlurper.parseText(file("${projectDir}/cycles_fertilizer_increase_output_parser_args.json").text)
cycles_output_summary_args = jsonSlurper.parseText(file("${projectDir}/cycles_output_summary_args.json").text)
cycles_fertilizer_increase_output_summary_args = jsonSlurper.parseText(file("${projectDir}/cycles_fertilizer_increase_output_summary_args.json").text)
cycles_plots_args = jsonSlurper.parseText(file("${projectDir}/cycles_plots_args.json").text)


process task_baseline_cycles {
  cpus 8
  memory '18.16 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "baseline_cycles_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py baseline_cycles_${id} ${baseline_cycles_args.get(id).get("resources")} --out "{${baseline_cycles_args.get(id).get("out")}}" \$inputs
  """
}
process task_cycles {
  cpus 7
  memory '16.36 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cycles_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cycles_${id} ${cycles_args.get(id).get("resources")} --out "{${cycles_args.get(id).get("out")}}" \$inputs
  """
}
process task_fertilizer_increase_cycles {
  cpus 7
  memory '16.44 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "fertilizer_increase_cycles_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py fertilizer_increase_cycles_${id} ${fertilizer_increase_cycles_args.get(id).get("resources")} --out "{${fertilizer_increase_cycles_args.get(id).get("out")}}" \$inputs
  """
}
process task_cycles_fertilizer_increase_output_parser {
  cpus 1
  memory '1.31 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cycles_fertilizer_increase_output_parser_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cycles_fertilizer_increase_output_parser_${id} ${cycles_fertilizer_increase_output_parser_args.get(id).get("resources")} --out "{${cycles_fertilizer_increase_output_parser_args.get(id).get("out")}}" \$inputs
  """
}
process task_cycles_output_summary {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cycles_output_summary_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cycles_output_summary_${id} ${cycles_output_summary_args.get(id).get("resources")} --out "{${cycles_output_summary_args.get(id).get("out")}}" \$inputs
  """
}
process task_cycles_fertilizer_increase_output_summary {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cycles_fertilizer_increase_output_summary_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cycles_fertilizer_increase_output_summary_${id} ${cycles_fertilizer_increase_output_summary_args.get(id).get("resources")} --out "{${cycles_fertilizer_increase_output_summary_args.get(id).get("out")}}" \$inputs
  """
}
process task_cycles_plots {
  cpus 3
  memory '8.80 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cycles_plots_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cycles_plots_${id} ${cycles_plots_args.get(id).get("resources")} --out "{${cycles_plots_args.get(id).get("out")}}" \$inputs
  """
}
workflow {
  workflow_inputs = Channel.fromPath("${params.indir}/*")

  baseline_cycles_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "baseline_cycles")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 6)
  baseline_cycles_out = task_baseline_cycles(baseline_cycles_in)

  concatenated_FOR_cycles = workflow_inputs.concat(baseline_cycles_out)
  cycles_in = concatenated_FOR_cycles.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cycles")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 9)
  cycles_out = task_cycles(cycles_in)

  concatenated_FOR_fertilizer_increase_cycles = workflow_inputs.concat(baseline_cycles_out)
  fertilizer_increase_cycles_in = concatenated_FOR_fertilizer_increase_cycles.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "fertilizer_increase_cycles")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 9)
  fertilizer_increase_cycles_out = task_fertilizer_increase_cycles(fertilizer_increase_cycles_in)

  concatenated_FOR_cycles_fertilizer_increase_output_parser = workflow_inputs.concat(cycles_out, fertilizer_increase_cycles_out)
  cycles_fertilizer_increase_output_parser_in = concatenated_FOR_cycles_fertilizer_increase_output_parser.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cycles_fertilizer_increase_output_parser")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 6)
  cycles_fertilizer_increase_output_parser_out = task_cycles_fertilizer_increase_output_parser(cycles_fertilizer_increase_output_parser_in)

  concatenated_FOR_cycles_output_summary = workflow_inputs.concat(cycles_out)
  cycles_output_summary_in = concatenated_FOR_cycles_output_summary.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cycles_output_summary")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.map { id, file -> tuple( groupKey(id, cycles_output_summary_input_amounts[id]), file ) }
  .groupTuple()
  cycles_output_summary_out = task_cycles_output_summary(cycles_output_summary_in)

  concatenated_FOR_cycles_fertilizer_increase_output_summary = workflow_inputs.concat(cycles_fertilizer_increase_output_parser_out)
  cycles_fertilizer_increase_output_summary_in = concatenated_FOR_cycles_fertilizer_increase_output_summary.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cycles_fertilizer_increase_output_summary")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.map { id, file -> tuple( groupKey(id, cycles_fertilizer_increase_output_summary_input_amounts[id]), file ) }
  .groupTuple()
  cycles_fertilizer_increase_output_summary_out = task_cycles_fertilizer_increase_output_summary(cycles_fertilizer_increase_output_summary_in)

  concatenated_FOR_cycles_plots = workflow_inputs.concat(cycles_output_summary_out)
  cycles_plots_in = concatenated_FOR_cycles_plots.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cycles_plots")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 10)
  cycles_plots_out = task_cycles_plots(cycles_plots_in)

  println("Workflow Synthetic_Cycles finished successfully.")
}
