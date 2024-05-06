
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
fastq_reduce_args = jsonSlurper.parseText(file("${projectDir}/fastq_reduce_args.json").text)
bwa_index_args = jsonSlurper.parseText(file("${projectDir}/bwa_index_args.json").text)
bwa_args = jsonSlurper.parseText(file("${projectDir}/bwa_args.json").text)
cat_bwa_args = jsonSlurper.parseText(file("${projectDir}/cat_bwa_args.json").text)
cat_args = jsonSlurper.parseText(file("${projectDir}/cat_args.json").text)


process task_fastq_reduce {
  cpus 1
  memory '1.45 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "fastq_reduce_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py fastq_reduce_${id} ${fastq_reduce_args.get(id).get("resources")} --out "{${fastq_reduce_args.get(id).get("out")}}" \$inputs
  """
}
process task_bwa_index {
  cpus 15
  memory '18.16 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "bwa_index_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py bwa_index_${id} ${bwa_index_args.get(id).get("resources")} --out "{${bwa_index_args.get(id).get("out")}}" \$inputs
  """
}
process task_bwa {
  cpus 4
  memory '6.18 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "bwa_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py bwa_${id} ${bwa_args.get(id).get("resources")} --out "{${bwa_args.get(id).get("out")}}" \$inputs
  """
}
process task_cat_bwa {
  cpus 6
  memory '8.50 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cat_bwa_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cat_bwa_${id} ${cat_bwa_args.get(id).get("resources")} --out "{${cat_bwa_args.get(id).get("out")}}" \$inputs
  """
}
process task_cat {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cat_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cat_${id} ${cat_args.get(id).get("resources")} --out "{${cat_args.get(id).get("out")}}" \$inputs
  """
}
workflow {
  workflow_inputs = Channel.fromPath("${params.indir}/*")

  fastq_reduce_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "fastq_reduce")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2)
  fastq_reduce_out = task_fastq_reduce(fastq_reduce_in)

  bwa_index_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "bwa_index")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2)
  bwa_index_out = task_bwa_index(bwa_index_in)

  concatenated_FOR_bwa = workflow_inputs.concat(fastq_reduce_out, bwa_index_out)
  bwa_in = concatenated_FOR_bwa.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "bwa")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 7)
  bwa_out = task_bwa(bwa_in)

  concatenated_FOR_cat_bwa = workflow_inputs.concat(bwa_out)
  cat_bwa_in = concatenated_FOR_cat_bwa.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cat_bwa")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2389)
  cat_bwa_out = task_cat_bwa(cat_bwa_in)

  concatenated_FOR_cat = workflow_inputs.concat(bwa_out)
  cat_in = concatenated_FOR_cat.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cat")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2388)
  cat_out = task_cat(cat_in)

  println("Workflow Synthetic_Bwa finished successfully.")
}
