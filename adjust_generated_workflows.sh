#!/usr/bin/env bash

cd $(dirname $0)

workflow_dirs=$(find generated_workflows -maxdepth 1 -type d -name "Synthetic_*" -printf '%P\n'| xargs)

rm -rd synthetics/
rm synthetics.zip
rm -rd configs/
rm configs.zip

for dir in $workflow_dirs; do
    echo "=== ${dir} ==="
    mkdir -p synthetics/${dir}/${dir}
    cp -v generated_workflows/${dir}/main.nf synthetics/${dir}/${dir}
    cp -v generated_workflows/${dir}/*.json synthetics/${dir}/${dir}

    mkdir -p synthetics/${dir}/input
    cp -v create.sh synthetics/${dir}/input
    cp -v generated_workflows/${dir}/to_create.txt synthetics/${dir}/input

    mkdir -p configs/${dir}
    cp -v HUnextflow.config configs/${dir}/nextflow.config
    cp -v HUloadToCache.yaml configs/${dir}/loadToCache.yaml

    sed -i "s/\/input\/input/\/input\/workflow-inputs\/${dir}/g" configs/${dir}/nextflow.config

    python3 adjust.py synthetics/${dir}/${dir}/main.nf >> configs/${dir}/nextflow.config
    grep -v "memory '*" generated_workflows/${dir}/main.nf | grep -v "cpus *" > synthetics/${dir}/${dir}/main.nf 
done
