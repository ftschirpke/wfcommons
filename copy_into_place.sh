#!/usr/bin/env bash

cd $(dirname $0)

synwfs=( Synthetic_Blast Synthetic_Bwa Synthetic_Cycles Synthetic_Genome Synthetic_Montage Synthetic_Seismology Synthetic_Soykb )

kubectl wait --timeout=100s --for=condition=ready pod nextflow && pod_ready=true || pod_ready=false
if [ $pod_ready = false ]; then
    echo "Unable to start nextflow pod on remote cluster. Exiting."
    exit 1
fi

for wf in "${synwfs[@]}"
do
    echo
    echo "======= $wf ======="

    echo "--- Copying $wf definiton into place ---"
    kubectl exec nextflow -- bash -c "rm -rd /input/workflows/$wf"
    kubectl cp synthetics/$wf/$wf nextflow:/input/workflows/$wf
    
    echo "--- Copying $wf inputs into place ---"
    kubectl exec nextflow -- bash -c "rm -rd /input/workflow-inputs/$wf"
    kubectl cp synthetics/$wf/input nextflow:/input/workflow-inputs/$wf

    echo "--- Copying $wf configs into place ---"
    rm -rd ../experiments/experiment/$wf
    cp -r configs/$wf ../experiments/experiment/$wf

    echo "--- Creating $wf inputs in remote cluster ---"
    kubectl exec nextflow -- bash -c "bash /input/workflow-inputs/$wf/create.sh /input/workflow-inputs/$wf/to_create.txt"
    kubectl exec nextflow -- bash -c "rm /input/workflow-inputs/$wf/create.sh /input/workflow-inputs/$wf/to_create.txt"
done
