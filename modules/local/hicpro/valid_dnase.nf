process HICPRO_VALID_DNASE {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::biopython=1.70" : null)
    container "${ workflow.containerEngine == 'singularity' &&
                    !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.70--np112py36_1' :
        'quay.io/biocontainers/biopython:1.70--np112py36_1' }"

    input:
    tuple val(meta), path(bam)
    path map_dnase_path
    val hicpro_version

    output:
    tuple val(meta), path("${prefix}.validPairs")   , emit: validpair
    tuple val(meta), path("${prefix}.RSstat")       , emit: stats
    path "versions.yml"                             , emit: versions

    script:
    def args   = task.ext.args ?: ''
    prefix = bam.toString() - ~/.bam/
    """
    python $map_dnase_path \\
        $args \\
        -r ${bam}

    sort -k2,2V -k3,3n -k5,5V -k6,6n \\
        -o ${prefix}.validPairs \\
        ${prefix}.validPairs

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        HiC-Pro: $hicpro_version
    END_VERSIONS
    """
}
