
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
def individuals_merge_input_amounts = [
  "00000026": 25,
  "00000053": 27,
  "00000080": 25,
  "00000107": 27,
  "00000134": 25,
  "00000161": 26,
  "00000188": 26,
  "00000215": 27,
  "00000242": 26,
  "00000269": 26,
  "00000296": 26,
  "00000323": 25,
  "00000350": 26,
  "00000377": 26,
  "00000624": 25,
  "00000630": 25,
]

file_inputs = jsonSlurper.parseText(file("${projectDir}/file_inputs.json").text)
individuals_args = jsonSlurper.parseText(file("${projectDir}/individuals_args.json").text)
individuals_merge_args = jsonSlurper.parseText(file("${projectDir}/individuals_merge_args.json").text)
sifting_args = jsonSlurper.parseText(file("${projectDir}/sifting_args.json").text)
mutation_overlap_args = jsonSlurper.parseText(file("${projectDir}/mutation_overlap_args.json").text)
frequency_args = jsonSlurper.parseText(file("${projectDir}/frequency_args.json").text)


process task_individuals {
  cpus 8
  memory '14.71 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "individuals_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py individuals_${id} ${individuals_args.get(id).get("resources")} --out "{${individuals_args.get(id).get("out")}}" \$inputs
  """
}
process task_individuals_merge {
  cpus 10
  memory '18.16 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "individuals_merge_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py individuals_merge_${id} ${individuals_merge_args.get(id).get("resources")} --out "{${individuals_merge_args.get(id).get("out")}}" \$inputs
  """
}
process task_sifting {
  cpus 1
  memory '2.46 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "sifting_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py sifting_${id} ${sifting_args.get(id).get("resources")} --out "{${sifting_args.get(id).get("out")}}" \$inputs
  """
}
process task_mutation_overlap {
  cpus 3
  memory '7.60 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "mutation_overlap_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py mutation_overlap_${id} ${mutation_overlap_args.get(id).get("resources")} --out "{${mutation_overlap_args.get(id).get("out")}}" \$inputs
  """
}
process task_frequency {
  cpus 7
  memory '13.66 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "frequency_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py frequency_${id} ${frequency_args.get(id).get("resources")} --out "{${frequency_args.get(id).get("out")}}" \$inputs
  """
}
workflow {
  workflow_inputs = Channel.fromPath("${params.indir}/*")

  individuals_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "individuals")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2)
  individuals_out = task_individuals(individuals_in)

  concatenated_FOR_individuals_merge = workflow_inputs.concat(individuals_out)
  individuals_merge_in = concatenated_FOR_individuals_merge.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "individuals_merge")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.map { id, file -> tuple( groupKey(id, individuals_merge_input_amounts[id]), file ) }
  .groupTuple()
  individuals_merge_out = task_individuals_merge(individuals_merge_in)

  sifting_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "sifting")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 1)
  sifting_out = task_sifting(sifting_in)

  concatenated_FOR_mutation_overlap = workflow_inputs.concat(individuals_merge_out, sifting_out)
  mutation_overlap_in = concatenated_FOR_mutation_overlap.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "mutation_overlap")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 9)
  mutation_overlap_out = task_mutation_overlap(mutation_overlap_in)

  concatenated_FOR_frequency = workflow_inputs.concat(individuals_merge_out, sifting_out)
  frequency_in = concatenated_FOR_frequency.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "frequency")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 9)
  frequency_out = task_frequency(frequency_in)

  println("Workflow Synthetic_Genome finished successfully.")
}
