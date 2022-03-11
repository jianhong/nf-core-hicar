process HICPRO_TRIM {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::coreutils=8.31" : null)
    container "${ workflow.containerEngine == 'singularity' &&
                    !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:8.31--h14c3975_0' :
        'quay.io/biocontainers/coreutils:8.31--h14c3975_0' }"

    input:
    tuple val(meta), path(reads)
    path cutsite_trimming
    path ligation_site
    val hicpro_version

    output:
    tuple val(meta), path("${prefix}_trimmed.fastq"), emit: reads
    path "versions.yml"                             , emit: versions

    script:
    def args   = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    g++ -std=c++0x -o cutsite_trimming $cutsite_trimming
    cutsite_trimming \\
        $args \\
        --fastq $reads \\
        --cutsite  $ligation_site \\
        --out ${prefix}_trimmed.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        $cutsite_trimming: $hicpro_version
    END_VERSIONS
    """
}
