
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

file_inputs = jsonSlurper.parseText(file("${projectDir}/file_inputs.json").text)
sG1IterDecon_args = jsonSlurper.parseText(file("${projectDir}/sG1IterDecon_args.json").text)
wrapper_siftSTFByMisfit_args = jsonSlurper.parseText(file("${projectDir}/wrapper_siftSTFByMisfit_args.json").text)


process task_sG1IterDecon {
  cpus 8
  memory '18.16 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "sG1IterDecon_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py sG1IterDecon_${id} ${sG1IterDecon_args.get(id).get("resources")} --out "{${sG1IterDecon_args.get(id).get("out")}}" \$inputs
  """
}
process task_wrapper_siftSTFByMisfit {
  cpus 1
  memory '1.50 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "wrapper_siftSTFByMisfit_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py wrapper_siftSTFByMisfit_${id} ${wrapper_siftSTFByMisfit_args.get(id).get("resources")} --out "{${wrapper_siftSTFByMisfit_args.get(id).get("out")}}" \$inputs
  """
}
workflow {
  workflow_inputs = Channel.fromPath("${params.indir}/*")

  sG1IterDecon_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "sG1IterDecon")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 1)
  sG1IterDecon_out = task_sG1IterDecon(sG1IterDecon_in)

  concatenated_FOR_wrapper_siftSTFByMisfit = workflow_inputs.concat(sG1IterDecon_out)
  wrapper_siftSTFByMisfit_in = concatenated_FOR_wrapper_siftSTFByMisfit.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "wrapper_siftSTFByMisfit")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 499)
  wrapper_siftSTFByMisfit_out = task_wrapper_siftSTFByMisfit(wrapper_siftSTFByMisfit_in)

  println("Workflow Synthetic_Seismology finished successfully.")
}
