
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
split_fasta_args = jsonSlurper.parseText(file("${projectDir}/split_fasta_args.json").text)
blastall_args = jsonSlurper.parseText(file("${projectDir}/blastall_args.json").text)
cat_blast_args = jsonSlurper.parseText(file("${projectDir}/cat_blast_args.json").text)
cat_args = jsonSlurper.parseText(file("${projectDir}/cat_args.json").text)


process task_split_fasta {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "split_fasta_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py split_fasta_${id} ${split_fasta_args.get(id).get("resources")} --out "{${split_fasta_args.get(id).get("out")}}" \$inputs
  """
}
process task_blastall {
  cpus 8
  memory '18.16 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "blastall_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py blastall_${id} ${blastall_args.get(id).get("resources")} --out "{${blastall_args.get(id).get("out")}}" \$inputs
  """
}
process task_cat_blast {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "cat_blast_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py cat_blast_${id} ${cat_blast_args.get(id).get("resources")} --out "{${cat_blast_args.get(id).get("out")}}" \$inputs
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

  split_fasta_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "split_fasta")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2)
  split_fasta_out = task_split_fasta(split_fasta_in)

  concatenated_FOR_blastall = workflow_inputs.concat(split_fasta_out)
  blastall_in = concatenated_FOR_blastall.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "blastall")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 3)
  blastall_out = task_blastall(blastall_in)

  concatenated_FOR_cat_blast = workflow_inputs.concat(blastall_out)
  cat_blast_in = concatenated_FOR_cat_blast.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cat_blast")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 791)
  cat_blast_out = task_cat_blast(cat_blast_in)

  concatenated_FOR_cat = workflow_inputs.concat(blastall_out)
  cat_in = concatenated_FOR_cat.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "cat")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 790)
  cat_out = task_cat(cat_in)

  println("Workflow Synthetic_Blast finished successfully.")
}
